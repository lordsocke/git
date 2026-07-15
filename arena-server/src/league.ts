import { randomInt } from "node:crypto";
import { pool } from "./db.js";
import { config } from "./config.js";
import { recordResult } from "./settlement.js";
import { resolveDailyPicks } from "./engagement.js";

// ---------------------------------------------------------------------------
// ARENA-Liga-Engine (B5): serverseitige virtuelle Spiele.
// Design-Entscheidung: Ein virtuelles Spiel ist eine NORMALE Zeile in `matches`
// (competition_id 'arena-liga'). Platzierung, Quoten-Autorität, Kombis und
// Settlement laufen damit über exakt dieselbe, bereits reviewte Maschinerie
// wie echte Spiele – die Liga-Engine erzeugt nur Runden und liefert Ergebnisse.
//
// Preisableitung = exakt das Simulationsmodell des Prototyps (Poisson-Splitting,
// Auszahlungsfaktor 0,925 ⇒ Hold 7,5 %, EV je Markt −7…−8 %). Das ERGEBNIS wird
// aus DEMSELBEN Modell gesampelt (gleiches λ/q), mit deterministischem, pro Runde
// gespeichertem Seed (league_rounds) – auditierbar und reproduzierbar.
// ---------------------------------------------------------------------------

const TEAMS = [
  { n: "Aurora FC", s: 82 },
  { n: "Union Kobalt", s: 78 },
  { n: "SC Meridian", s: 75 },
  { n: "Athletico Nova", s: 73 },
  { n: "FC Boreas", s: 70 },
  { n: "Sparta Lyra", s: 67 },
  { n: "Dynamo Quarz", s: 64 },
  { n: "Real Zephyr", s: 60 },
] as const;

const PAYOUT = 0.925; // Hold 7,5 %
const LAMBDA = 2.685; // Gesamt-Torerwartung pro Spiel (kalibriert im Prototyp)

const clamp = (v: number, a: number, b: number): number => Math.max(a, Math.min(b, v));
const r2 = (v: number): number => Math.round(clamp(v, 1.03, 29) * 100) / 100;

function poisArr(lam: number, n: number): number[] {
  const a = [Math.exp(-lam)];
  for (let k = 1; k <= n; k++) a.push(a[k - 1]! * (lam / k));
  return a;
}

/** Pre-Match-Quoten aus dem Poisson-Modell (EV je Markt = −7,5 %). */
export function priceMarkets(q: number, lambda: number = LAMBDA): Record<string, Record<string, number>> {
  const N = 12;
  const ph = poisArr(lambda * q, N);
  const pa = poisArr(lambda * (1 - q), N);
  let p1 = 0;
  let px = 0;
  let p2 = 0;
  let pOver = 0;
  for (let i = 0; i <= N; i++) {
    for (let j = 0; j <= N; j++) {
      const p = ph[i]! * pa[j]!;
      if (i > j) p1 += p;
      else if (i < j) p2 += p;
      else px += p;
      if (i + j > 2.5) pOver += p;
    }
  }
  const markets: Record<string, Record<string, number>> = {
    "1X2": { "1": r2(PAYOUT / Math.max(p1, 0.033)), X: r2(PAYOUT / Math.max(px, 0.033)), "2": r2(PAYOUT / Math.max(p2, 0.033)) },
  };
  if (pOver > 0.005 && pOver < 0.995) {
    markets.OU25 = { over: r2(PAYOUT / pOver), under: r2(PAYOUT / (1 - pOver)) };
  }
  return markets;
}

// --- Deterministischer RNG (Audit/Replay) ------------------------------------

/** mulberry32: klein, deterministisch, für Sim-Zwecke völlig ausreichend. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function samplePoisson(lam: number, rnd: () => number): number {
  const limit = Math.exp(-lam);
  let k = 0;
  let p = 1;
  do {
    k++;
    p *= rnd();
  } while (p > limit && k < 15);
  return k - 1;
}

/** Endergebnis deterministisch aus Seed + Modellparametern (reproduzierbar). */
export function sampleResult(seed: number, q: number, lambda: number): { home: number; away: number } {
  const rnd = mulberry32(seed);
  return {
    home: samplePoisson(lambda * q, rnd),
    away: samplePoisson(lambda * (1 - q), rnd),
  };
}

// --- Runden-Lebenszyklus -------------------------------------------------------

export interface LeagueRound {
  matchId: string;
  home: string;
  away: string;
  kickoff: string; // Wett-Annahmeschluss = Kickoff (Platzierungs-Guard greift automatisch)
  settleAt: string;
  odds: Record<string, Record<string, number>>;
  status: string;
}

/**
 * Sicherstellen, dass eine offene Runde existiert (Wettfenster läuft).
 * Idempotent – erzeugt nur dann eine neue Runde, wenn keine ansteht.
 */
export async function ensureLeagueRound(): Promise<LeagueRound> {
  const open = await currentRound();
  if (open) return open;

  // Paarung + Modellparameter
  const h = randomInt(TEAMS.length);
  let a = randomInt(TEAMS.length);
  if (a === h) a = (a + 1 + randomInt(TEAMS.length - 1)) % TEAMS.length;
  const q = clamp(0.53 + (TEAMS[h]!.s - TEAMS[a]!.s) * 0.01, 0.15, 0.85);
  const seed = randomInt(2_147_483_647);

  const kickoff = new Date(Date.now() + config.leagueBettingSeconds * 1000);
  const settleAt = new Date(kickoff.getTime() + config.leagueLiveSeconds * 1000);
  const matchId = `liga-${Date.now()}-${seed % 1000}`;
  const odds = priceMarkets(q);

  await pool.query(
    `insert into matches (id, competition_id, competition_name, home, away, kickoff, odds)
     values ($1, 'arena-liga', 'ARENA Liga', $2, $3, $4, $5)`,
    [matchId, TEAMS[h]!.n, TEAMS[a]!.n, kickoff.toISOString(), JSON.stringify(odds)],
  );
  await pool.query(
    "insert into league_rounds (match_id, seed, q, lambda, settle_at) values ($1, $2, $3, $4, $5)",
    [matchId, seed, q.toFixed(4), LAMBDA.toFixed(4), settleAt.toISOString()],
  );

  return {
    matchId,
    home: TEAMS[h]!.n,
    away: TEAMS[a]!.n,
    kickoff: kickoff.toISOString(),
    settleAt: settleAt.toISOString(),
    odds,
    status: "scheduled",
  };
}

/** Aktuelle Runde (Wettfenster offen ODER live, noch nicht abgerechnet). */
export async function currentRound(): Promise<LeagueRound | null> {
  const { rows } = await pool.query(
    `select m.id, m.home, m.away, m.kickoff, m.odds, m.status, r.settle_at
     from matches m join league_rounds r on r.match_id = m.id
     where m.status = 'scheduled' and not r.settled
     order by m.kickoff desc limit 1`,
  );
  const m = rows[0];
  if (!m) return null;
  return {
    matchId: m.id,
    home: m.home,
    away: m.away,
    kickoff: m.kickoff.toISOString(),
    settleAt: m.settle_at.toISOString(),
    odds: m.odds,
    status: m.status,
  };
}

/**
 * Fällige Runden abrechnen: Ergebnis deterministisch aus dem gespeicherten Seed
 * sampeln und über die reguläre Settlement-Engine verbuchen. Idempotent.
 */
export async function settleDueLeagueRounds(): Promise<number> {
  const { rows } = await pool.query<{ match_id: string; seed: string; q: string; lambda: string }>(
    "select match_id, seed, q, lambda from league_rounds where not settled and settle_at <= now()",
  );
  let settled = 0;
  for (const r of rows) {
    const { home, away } = sampleResult(Number(r.seed), Number(r.q), Number(r.lambda));
    await recordResult(r.match_id, home, away);
    await resolveDailyPicks(r.match_id, home, away); // Tages-Tipps dieser Runde auflösen
    await pool.query("update league_rounds set settled = true where match_id = $1", [r.match_id]);
    settled++;
  }
  return settled;
}

/** Ein Takt des Liga-Treibers: fällige Runden abrechnen, neue Runde sicherstellen. */
export async function leagueTick(): Promise<{ settled: number; round: LeagueRound }> {
  const settled = await settleDueLeagueRounds();
  const round = await ensureLeagueRound();
  return { settled, round };
}
