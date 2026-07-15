import type { Client } from "./db.js";
import { pool, withTx } from "./db.js";
import { config } from "./config.js";
import { postManyIn } from "./wallet.js";
import { addXpIn, bumpChallengeIn, levelOf, maxStakeFor } from "./engagement.js";

// ---------------------------------------------------------------------------
// Bet-Service (B3): server-autoritative Platzierung.
// Der Client sendet NUR (matchId, market, pick) + stake + idempotencyKey.
// Bepreist wird ausschließlich aus matches.odds – manipulierte Client-Quoten
// sind damit konstruktionsbedingt wirkungslos.
// ---------------------------------------------------------------------------

export type Market = "1X2" | "OU25";

export interface LegInput {
  matchId: string;
  market: Market;
  pick: string; // '1'|'X'|'2' bzw. 'over'|'under'
}

export interface BetView {
  id: string;
  stake: number;
  totalOdds: number;
  status: string;
  payout: number | null;
  placedAt: string;
  legs: Array<{
    matchId: string;
    home: string;
    away: string;
    market: Market;
    pick: string;
    odds: number;
    status: string;
  }>;
}

/** Fachlicher Platzierungsfehler → HTTP 422. */
export class PlacementError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = "PlacementError";
  }
}

const VALID_PICKS: Record<Market, ReadonlySet<string>> = {
  "1X2": new Set(["1", "X", "2"]),
  OU25: new Set(["over", "under"]),
};

interface MatchRow {
  id: string;
  competition_id: string;
  home: string;
  away: string;
  kickoff: Date;
  status: string;
  odds: Record<string, Record<string, number>>;
  odds_version: number;
}

/**
 * Idempotenz-Treffer prüfen: Der Key muss DEMSELBEN Nutzer gehören und die
 * Wiederholung muss dieselbe Wette meinen (Stake + Auswahlen identisch).
 * Ein fremder oder wiederverwendeter Key ist ein Fehler – niemals stillschweigend
 * eine (womöglich fremde) andere Wette als "Erfolg" zurückgeben (Review-Finding).
 */
async function resolveIdempotent(
  betId: string,
  ownerUserId: string,
  userId: string,
  stake: number,
  legs: LegInput[],
  client?: Client,
): Promise<BetView> {
  if (ownerUserId !== userId) {
    throw new PlacementError("idempotency_conflict", "idempotencyKey ist bereits vergeben");
  }
  const view = await getBet(betId, client);
  if (!view) throw new Error("Bet zum Idempotenz-Key verschwunden");
  const sameLegs =
    view.legs.length === legs.length &&
    legs.every((l) => view.legs.some((v) => v.matchId === l.matchId && v.market === l.market && v.pick === l.pick));
  if (view.stake !== stake || !sameLegs) {
    throw new PlacementError(
      "idempotency_mismatch",
      "idempotencyKey wurde bereits für eine andere Wette verwendet",
    );
  }
  return view;
}

/**
 * Wette platzieren. Atomar in EINER Transaktion:
 * Validierung → Quoten-Lookup (FOR SHARE) → Bet+Legs anlegen → Einsatz abbuchen.
 * Idempotent über den Client-Key: Wiederholung liefert dieselbe Wette, bucht nie doppelt.
 */
export async function placeBet(
  userId: string,
  stake: number,
  legs: LegInput[],
  idempotencyKey: string,
): Promise<BetView> {
  // --- Eingaben prüfen (außerhalb der Tx, rein fachlich) ---
  if (!idempotencyKey || idempotencyKey.length > 120) {
    throw new PlacementError("bad_idempotency_key", "idempotencyKey fehlt oder ist zu lang");
  }
  if (!Number.isInteger(stake) || stake < config.minStake || stake > config.maxStake) {
    throw new PlacementError("bad_stake", `Einsatz muss ganzzahlig zwischen ${config.minStake} und ${config.maxStake} liegen`);
  }
  if (!Array.isArray(legs) || legs.length < 1 || legs.length > config.maxComboLegs) {
    throw new PlacementError("bad_legs", `1 bis ${config.maxComboLegs} Auswahlen erlaubt`);
  }
  const matchIds = legs.map((l) => l.matchId);
  if (new Set(matchIds).size !== matchIds.length) {
    throw new PlacementError("duplicate_match", "Jedes Spiel darf pro Wette nur einmal vorkommen");
  }
  for (const leg of legs) {
    if (!VALID_PICKS[leg.market]?.has(leg.pick)) {
      throw new PlacementError("bad_pick", `Ungültige Auswahl ${leg.market}/${leg.pick}`);
    }
  }

  try {
    return await placeBetTx(userId, stake, legs, idempotencyKey);
  } catch (err) {
    // Check-then-insert-Race: Zwei gleichzeitige Erst-Platzierungen mit demselben
    // Key → der zweite Insert läuft in unique_violation (23505). Das ist der
    // idempotente Fall, kein interner Fehler (Review-Finding) → Treffer auflösen.
    const pgErr = err as { code?: string; constraint?: string };
    if (pgErr.code === "23505" && pgErr.constraint?.includes("idempotency")) {
      const { rows } = await pool.query<{ id: string; user_id: string }>(
        "select id, user_id from bets where idempotency_key = $1",
        [idempotencyKey],
      );
      if (rows[0]) return resolveIdempotent(rows[0].id, rows[0].user_id, userId, stake, legs);
    }
    throw err;
  }
}

async function placeBetTx(
  userId: string,
  stake: number,
  legs: LegInput[],
  idempotencyKey: string,
): Promise<BetView> {
  return withTx(async (c) => {
    // Idempotenz: existiert diese Platzierung bereits? → prüfen und zurückgeben.
    const existing = await c.query<{ id: string; user_id: string }>(
      "select id, user_id from bets where idempotency_key = $1",
      [idempotencyKey],
    );
    if (existing.rowCount && existing.rows[0]) {
      return resolveIdempotent(existing.rows[0].id, existing.rows[0].user_id, userId, stake, legs, c);
    }

    // Spiele lesen und mit FOR SHARE fixieren: verhindert die Race, dass ein Spiel
    // WÄHREND der Platzierung abgerechnet wird (Settlement nimmt die Zeilensperre).
    const { rows: matches } = await c.query<MatchRow>(
      "select id, competition_id, home, away, kickoff, status, odds, odds_version from matches where id = any($1) for share",
      [legs.map((l) => l.matchId)],
    );
    const byId = new Map(matches.map((m) => [m.id, m]));

    const now = Date.now();
    const priced: Array<{ leg: LegInput; match: MatchRow; odds: number }> = [];
    for (const leg of legs) {
      const match = byId.get(leg.matchId);
      if (!match) throw new PlacementError("unknown_match", `Unbekanntes Spiel: ${leg.matchId}`);
      if (match.status !== "scheduled") throw new PlacementError("match_closed", `${match.home} – ${match.away} ist nicht mehr offen`);
      if (match.kickoff.getTime() <= now) throw new PlacementError("kickoff_passed", `${match.home} – ${match.away} hat bereits begonnen`);
      const odds = match.odds?.[leg.market]?.[leg.pick];
      if (typeof odds !== "number" || odds <= 1) {
        throw new PlacementError("market_unavailable", `Markt ${leg.market} für ${leg.matchId} nicht verfügbar`);
      }
      priced.push({ leg, match, odds });
    }

    // Level-Cap des Einsatzes (B7): Max-Einsatz wächst mit dem Spielerlevel –
    // serverseitig durchgesetzt, damit der Client den Cap nicht umgehen kann.
    const level = await levelOf(userId, c);
    const cap = maxStakeFor(level);
    if (stake > cap) {
      throw new PlacementError("stake_above_level_cap", `Max-Einsatz auf Level ${level}: ${cap}`);
    }

    const totalOdds = priced.reduce((p, x) => p * x.odds, 1);

    const inserted = await c.query<{ id: string; placed_at: Date }>(
      `insert into bets (user_id, stake, total_odds, idempotency_key)
       values ($1, $2, $3, $4) returning id, placed_at`,
      [userId, stake, totalOdds.toFixed(4), idempotencyKey],
    );
    const betId = inserted.rows[0]!.id;

    for (const { leg, match, odds } of priced) {
      await c.query(
        `insert into bet_legs (bet_id, match_id, market, pick, odds, odds_version)
         values ($1, $2, $3, $4, $5, $6)`,
        [betId, leg.matchId, leg.market, leg.pick, odds.toFixed(4), match.odds_version],
      );
    }

    // Einsatz abbuchen – gleiche Tx: schlägt das fehl (z. B. zu wenig Coins),
    // verschwindet auch die Wette (Rollback). Ledger-Key deterministisch je Bet.
    // Lock-Reihenfolge: users (postManyIn) VOR engagement (addXpIn).
    await postManyIn(c, userId, [
      {
        amount: -stake,
        reason: "bet_stake",
        idempotencyKey: `bet:${betId}:stake`,
        refType: "bet",
        refId: betId,
      },
    ]);

    // Aktivitäts-XP: 10 je Tipp (deckungsgleich mit der App-Ökonomie) + Challenges.
    await addXpIn(c, userId, 10);
    await bumpChallengeIn(c, userId, "bets");
    if (priced.some((x) => x.match.competition_id === "arena-liga")) {
      await bumpChallengeIn(c, userId, "virt");
    }

    const view = await getBet(betId, c);
    if (!view) throw new Error("Bet nach Insert nicht lesbar");
    return view;
  });
}

/** Eine Wette mit Legs lesen (optional innerhalb einer bestehenden Tx). */
export async function getBet(betId: string, client?: Client): Promise<BetView | null> {
  const runner = client ?? pool;
  const { rows } = await runner.query(
    `select b.id, b.stake, b.total_odds, b.status, b.payout, b.placed_at,
            l.match_id, l.market, l.pick, l.odds as leg_odds, l.status as leg_status,
            m.home, m.away
     from bets b
     join bet_legs l on l.bet_id = b.id
     join matches m on m.id = l.match_id
     where b.id = $1
     order by l.id`,
    [betId],
  );
  if (!rows.length) return null;
  const b = rows[0];
  return {
    id: b.id,
    stake: b.stake,
    totalOdds: Number(b.total_odds),
    status: b.status,
    payout: b.payout,
    placedAt: b.placed_at.toISOString(),
    legs: rows.map((r) => ({
      matchId: r.match_id,
      home: r.home,
      away: r.away,
      market: r.market,
      pick: r.pick,
      odds: Number(r.leg_odds),
      status: r.leg_status,
    })),
  };
}

/** Wetten eines Nutzers (neueste zuerst). */
export async function listBets(userId: string, limit = 50): Promise<BetView[]> {
  const { rows } = await pool.query<{ id: string }>(
    "select id from bets where user_id = $1 order by placed_at desc, id desc limit $2",
    [userId, Math.min(limit, 200)],
  );
  const views: BetView[] = [];
  for (const r of rows) {
    const v = await getBet(r.id);
    if (v) views.push(v);
  }
  return views;
}

/** Anstehende Spiele mit Quoten (für die App-Match-Liste). */
export async function listMatches(): Promise<Array<Record<string, unknown>>> {
  const { rows } = await pool.query(
    `select id, competition_id, competition_name, home, away, kickoff, status, odds, odds_updated_at
     from matches
     where status = 'scheduled' and kickoff > now() - interval '3 hours'
     order by kickoff asc
     limit 500`,
  );
  return rows.map((r) => ({
    id: r.id,
    competitionId: r.competition_id,
    competitionName: r.competition_name,
    home: r.home,
    away: r.away,
    kickoff: r.kickoff.toISOString(),
    status: r.status,
    odds: r.odds,
    oddsUpdatedAt: r.odds_updated_at.toISOString(),
  }));
}
