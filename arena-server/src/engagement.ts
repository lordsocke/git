import { randomInt } from "node:crypto";
import type { Client } from "./db.js";
import { pool, withTx } from "./db.js";
import { config } from "./config.js";
import { postManyIn, type PostSpec } from "./wallet.js";

// ---------------------------------------------------------------------------
// Engagement-Service (B7-Kern): XP/Level, 3h-Bonus + Serie + Rad, Freispiele.
// Formeln sind DECKUNGSGLEICH mit der App („Start klein → Millionär",
// arena-economy-sim/tune_startsmall.py):
//   * Faucets wachsen +11 %/Level (Cap L55), Basis-Bonus 60.
//   * Max-Einsatz wächst +16,5 %/Level (Cap L55) – schneller als die Faucets.
//   * XP ist AKTIVITÄTS-basiert (Tipp 10 · Freispiel 4 · Claim 12 · Level-Kurve 70·L^0,76).
// Coins fließen ausschließlich über das Ledger (bonus_claim/wheel/freespin_win/levelup).
// ---------------------------------------------------------------------------

// --- Ökonomie-Formeln (Quelle der Wahrheit serverseitig) --------------------

export function xpNeeded(level: number): number {
  return Math.round(70 * Math.pow(level, 0.76));
}

export function levelFromXp(xp: number): number {
  let level = 1;
  let rest = xp;
  while (rest >= xpNeeded(level) && level < 200) {
    rest -= xpNeeded(level);
    level++;
  }
  return level;
}

const growth = (level: number): number => Math.pow(1.11, Math.min(level, 55) - 1);

export function bonusBase(level: number): number {
  return Math.round(60 * growth(level));
}

/** Festbeträge (Challenges, Chest, Tages-Tipp …) skalieren mit derselben Kurve. */
export function scaledForLevel(base: number, level: number): number {
  return Math.round(base * growth(level));
}

export function levelUpBonus(level: number): number {
  return Math.round(300 * growth(level));
}

/** Max-Einsatz am Level gecapt: +16,5 %/Level, L1 = 40, Cap-Level 55 ≈ 150 T. */
export function maxStakeFor(level: number): number {
  const raw = 40 * Math.pow(1.165, Math.min(level, 55) - 1);
  return Math.max(config.minStake, Math.min(Math.floor(raw / 10) * 10, config.maxStake));
}

export function streakMult(streak: number): number {
  return 1 + 0.07 * Math.min(streak, 7);
}

/** Bonus-Rad: exakt die App-Segmente (Coin-EV ≈ 3,05× · Ø 1,79 Spins · 0,21 Karten). */
export const WHEEL_SEGMENTS = [
  { id: 0, label: "2×", coinMult: 2, freeSpins: 0, cards: 0, weight: 26 },
  { id: 1, label: "5 Spins", coinMult: 0, freeSpins: 5, cards: 0, weight: 14 },
  { id: 2, label: "3×", coinMult: 3, freeSpins: 0, cards: 0, weight: 20 },
  { id: 3, label: "15 Spins", coinMult: 0, freeSpins: 15, cards: 0, weight: 7 },
  { id: 4, label: "5×", coinMult: 5, freeSpins: 0, cards: 0, weight: 13 },
  { id: 5, label: "+3 Karten", coinMult: 0, freeSpins: 0, cards: 3, weight: 7 },
  { id: 6, label: "8×", coinMult: 8, freeSpins: 0, cards: 0, weight: 9 },
  { id: 7, label: "JACKPOT 25×", coinMult: 25, freeSpins: 0, cards: 0, weight: 2 },
] as const;

const WHEEL_TOTAL_WEIGHT = WHEEL_SEGMENTS.reduce((s, x) => s + x.weight, 0);

function drawWheelSegment(): (typeof WHEEL_SEGMENTS)[number] {
  let r = randomInt(WHEEL_TOTAL_WEIGHT);
  for (const seg of WHEEL_SEGMENTS) {
    r -= seg.weight;
    if (r < 0) return seg;
  }
  return WHEEL_SEGMENTS[0];
}

/**
 * Freispiel-Ausgang: Gewinn-Multiplikator × Einsatzbasis (0,5 × Bonus-Basis).
 * Verteilung mit EV ≈ 0,4809 – kalibriert auf das App-Minigame (MINIGAME_EV der
 * Ökonomie-Sim). Die exakte Grid-Parität mit der App ist ein C2-Punkt (die App
 * animiert dann das Server-Ergebnis).
 */
const SPIN_OUTCOMES = [
  { mult: 0, weight: 626 },
  { mult: 0.5, weight: 200 },
  { mult: 1, weight: 100 },
  { mult: 2, weight: 50 },
  { mult: 5, weight: 20 },
  { mult: 20, weight: 4 },
] as const;
// EV = (0,5·200 + 1·100 + 2·50 + 5·20 + 20·4)/1000 = 480/1000 = 0,480 ≈ MINIGAME_EV 0,4809.

const SPIN_TOTAL_WEIGHT = SPIN_OUTCOMES.reduce((s, x) => s + x.weight, 0);

function drawSpinMult(): number {
  let r = randomInt(SPIN_TOTAL_WEIGHT);
  for (const o of SPIN_OUTCOMES) {
    r -= o.weight;
    if (r < 0) return o.mult;
  }
  return 0;
}

const utcDayNum = (): number => Math.floor(Date.now() / 86_400_000);

// --- Daily Challenges (L1-Anker, level-skaliert; Reset je UTC-Tag) -----------

export const CHALLENGE_DEFS = [
  { id: "bets", label: "2 Tipps platzieren", target: 2, coins: 50 },
  { id: "virt", label: "1 Wette in der ARENA Liga", target: 1, coins: 35 },
  { id: "bonus", label: "2× Arena Bonus abholen", target: 2, coins: 45 },
  { id: "spins", label: "5 Freispiele nutzen", target: 5, coins: 35 },
] as const;

export type ChallengeId = (typeof CHALLENGE_DEFS)[number]["id"];

const CHEST_COINS = 120; // level-skaliert; +2 Freispiele + 30 XP

interface ChallengeState {
  day?: number;
  vals?: Record<string, number>;
  done?: Record<string, boolean>;
  chestDone?: boolean;
}

// --- Stadion (Meta-Sink, boostet den Bonus) -----------------------------------

export const STADIUM_PARTS = ["tribune", "flutlicht", "rasen", "fanshop"] as const;
export const STADIUM_MAX_LEVEL = 5;

/** Ausbaustufe n kostet 250 × 2^(n−1) — level-UNabhängig (bewusst früh abschließbarer Meilenstein). */
export function stadiumCost(currentLevel: number): number {
  return 250 * Math.pow(2, currentLevel);
}

function stadiumTotal(stadium: Record<string, number>): number {
  return STADIUM_PARTS.reduce((s, p) => s + (stadium[p] ?? 0), 0);
}

/** Bonus-Multiplikator: Serie × Stadion (+1,5 %/Stufe), GESAMT gedeckelt auf ×2,0. */
export function bonusTotalMult(streak: number, stadium: Record<string, number>): number {
  return Math.min(streakMult(streak) * (1 + 0.015 * stadiumTotal(stadium)), 2.0);
}

// --- Zustand -----------------------------------------------------------------

export interface EngagementState {
  xp: number;
  level: number;
  xpIntoLevel: number;
  xpNeed: number;
  freeSpins: number;
  cards: number;
  ring: number;
  streak: number;
  bonusReadyAt: string | null;
  maxStake: number;
  bonusAmountNext: number;
  stadium: Record<string, number>;
  challenges: Array<{ id: string; label: string; target: number; progress: number; done: boolean; coins: number }>;
  chestDone: boolean;
  chestCoins: number;
  pick: { matchId: string | null; choice: string | null } | null;
  pickStreak: number;
  pickBest: number;
}

interface EngRow {
  xp: number;
  free_spins: number;
  cards: number;
  ring: number;
  streak: number;
  last_claim_day: number | null;
  bonus_ready_at: Date | null;
  stadium: Record<string, number>;
  challenges: ChallengeState;
  pick_day: number | null;
  pick_match: string | null;
  pick_choice: string | null;
  pick_streak: number;
  pick_best: number;
}

const ENG_COLS =
  "xp, free_spins, cards, ring, streak, last_claim_day, bonus_ready_at, stadium, challenges, pick_day, pick_match, pick_choice, pick_streak, pick_best";

/** Engagement-Zeile lesen/anlegen und sperren (Aufruf NUR innerhalb einer Tx, users-Sperre zuerst!). */
async function lockEngagement(c: Client, userId: string): Promise<EngRow> {
  await c.query("insert into engagement (user_id) values ($1) on conflict (user_id) do nothing", [userId]);
  const { rows } = await c.query<EngRow>(`select ${ENG_COLS} from engagement where user_id = $1 for update`, [userId]);
  return rows[0]!;
}

function toState(r: EngRow): EngagementState {
  const level = levelFromXp(r.xp);
  let rest = r.xp;
  for (let l = 1; l < level; l++) rest -= xpNeeded(l);
  const day = utcDayNum();
  const ch = r.challenges?.day === day ? r.challenges : {};
  return {
    xp: r.xp,
    level,
    xpIntoLevel: rest,
    xpNeed: xpNeeded(level),
    freeSpins: r.free_spins,
    cards: r.cards,
    ring: r.ring,
    streak: r.streak,
    bonusReadyAt: r.bonus_ready_at ? r.bonus_ready_at.toISOString() : null,
    maxStake: maxStakeFor(level),
    bonusAmountNext: Math.round(bonusBase(level) * bonusTotalMult(r.streak, r.stadium ?? {})),
    stadium: r.stadium ?? {},
    challenges: CHALLENGE_DEFS.map((d) => ({
      id: d.id,
      label: d.label,
      target: d.target,
      progress: Math.min(ch.vals?.[d.id] ?? 0, d.target),
      done: ch.done?.[d.id] === true,
      coins: scaledForLevel(d.coins, level),
    })),
    chestDone: ch.chestDone === true,
    chestCoins: scaledForLevel(CHEST_COINS, level),
    pick: r.pick_day === day ? { matchId: r.pick_match, choice: r.pick_choice } : null,
    pickStreak: r.pick_streak,
    pickBest: r.pick_best,
  };
}

export async function getEngagement(userId: string): Promise<EngagementState> {
  await pool.query("insert into engagement (user_id) values ($1) on conflict (user_id) do nothing", [userId]);
  const { rows } = await pool.query<EngRow>(`select ${ENG_COLS} from engagement where user_id = $1`, [userId]);
  return toState(rows[0]!);
}

/** Aktuelles Level eines Nutzers (für den Einsatz-Cap in placeBet). */
export async function levelOf(userId: string, c?: Client): Promise<number> {
  const runner = c ?? pool;
  const { rows } = await runner.query<{ xp: number }>("select xp from engagement where user_id = $1", [userId]);
  return levelFromXp(rows[0]?.xp ?? 0);
}

/**
 * Aktivitäts-XP gutschreiben (in bestehender Tx; users-Zeile muss bereits gesperrt
 * sein – Lock-Reihenfolge users → engagement, sonst Deadlock-Gefahr).
 * Level-ups zahlen den Level-up-Bonus über das Ledger und schenken 3 Freispiele.
 */
export async function addXpIn(c: Client, userId: string, points: number): Promise<{ levelUps: number[] }> {
  const row = await lockEngagement(c, userId);
  const before = levelFromXp(row.xp);
  const newXp = row.xp + Math.max(1, Math.round(points));
  const after = levelFromXp(newXp);

  const levelUps: number[] = [];
  let bonusSpins = 0;
  const posts = [];
  for (let l = before + 1; l <= after; l++) {
    levelUps.push(l);
    bonusSpins += 3;
    posts.push({
      amount: levelUpBonus(l),
      reason: "levelup" as const,
      idempotencyKey: `levelup:${userId}:${l}`, // je Level genau einmal
      refType: "level",
      refId: String(l),
    });
  }
  await c.query("update engagement set xp = $2, free_spins = free_spins + $3, updated_at = now() where user_id = $1", [
    userId,
    newXp,
    bonusSpins,
  ]);
  if (posts.length) await postManyIn(c, userId, posts);
  return { levelUps };
}

// --- Bonus-Claim (3h-Takt, Serie, jeder 3. Claim = Rad) -----------------------

export class ClaimNotReadyError extends Error {
  constructor(public readonly readyAt: Date) {
    super(`Bonus erst wieder ab ${readyAt.toISOString()} bereit`);
    this.name = "ClaimNotReadyError";
  }
}

export interface ClaimResult {
  amount: number;
  freeSpins: number;
  streak: number;
  wheel: { label: string; coinWin: number; freeSpins: number; cards: number } | null;
  balance: number;
  state: EngagementState;
}

export async function claimBonus(userId: string): Promise<ClaimResult> {
  return withTx(async (c) => {
    // Lock-Reihenfolge: IMMER zuerst die users-Zeile, dann engagement.
    await c.query("select id from users where id = $1 for update", [userId]);
    const row = await lockEngagement(c, userId);

    if (row.bonus_ready_at && row.bonus_ready_at.getTime() > Date.now()) {
      throw new ClaimNotReadyError(row.bonus_ready_at);
    }

    const level = levelFromXp(row.xp);
    const day = utcDayNum();
    const streak = row.last_claim_day === day ? row.streak : row.last_claim_day === day - 1 ? row.streak + 1 : 1;
    const amount = Math.round(bonusBase(level) * bonusTotalMult(streak, row.stadium ?? {}));

    const ring = row.ring + 1;
    const special = ring >= 3;
    const claimSeq = `${day}:${Date.now()}`;

    const posts: PostSpec[] = [
      {
        amount,
        reason: "bonus_claim",
        idempotencyKey: `bonus:${userId}:${claimSeq}`,
        refType: "bonus",
        refId: String(day),
      },
    ];

    // Rad sofort serverseitig drehen (die App animiert das Ergebnis).
    let wheel: ClaimResult["wheel"] = null;
    if (special) {
      const seg = drawWheelSegment();
      const coinWin = seg.coinMult > 0 ? amount * seg.coinMult : 0;
      wheel = { label: seg.label, coinWin, freeSpins: seg.freeSpins, cards: seg.cards };
      if (coinWin > 0) {
        posts.push({
          amount: coinWin,
          reason: "wheel" as const,
          idempotencyKey: `wheel:${userId}:${claimSeq}`,
          refType: "wheel",
          refId: seg.label,
        });
      }
    }

    const results = await postManyIn(c, userId, posts);
    const balance = results[results.length - 1]!.balance;

    await c.query(
      `update engagement set
         ring = $2, streak = $3, last_claim_day = $4,
         free_spins = free_spins + $5, cards = cards + $6,
         bonus_ready_at = now() + make_interval(hours => $7),
         updated_at = now()
       where user_id = $1`,
      [userId, special ? 0 : ring, streak, day, 2 + (wheel?.freeSpins ?? 0), wheel?.cards ?? 0, config.bonusCooldownHours],
    );

    // Claim-XP (Level-up kann weitere Buchungen auslösen; users-Sperre halten wir).
    await addXpIn(c, userId, 12);
    await bumpChallengeIn(c, userId, "bonus");

    const fresh = await c.query<EngRow>(
      "select xp, free_spins, cards, ring, streak, last_claim_day, bonus_ready_at from engagement where user_id = $1",
      [userId],
    );
    return { amount, freeSpins: 2 + (wheel?.freeSpins ?? 0), streak, wheel, balance, state: toState(fresh.rows[0]!) };
  });
}

// --- Freispiele (Arena Spins) --------------------------------------------------

export class NoSpinsError extends Error {
  constructor() {
    super("Keine Freispiele übrig");
    this.name = "NoSpinsError";
  }
}

export interface SpinResult {
  win: number;
  stakeBase: number;
  mult: number;
  freeSpinsLeft: number;
  balance: number | null; // null, wenn kein Gewinn (keine Buchung nötig)
}

export async function playSpin(userId: string): Promise<SpinResult> {
  return withTx(async (c) => {
    await c.query("select id from users where id = $1 for update", [userId]);
    const row = await lockEngagement(c, userId);
    if (row.free_spins <= 0) throw new NoSpinsError();

    const level = levelFromXp(row.xp);
    const stakeBase = Math.max(10, Math.round(bonusBase(level) * 0.5));
    const mult = drawSpinMult();
    const win = Math.round(stakeBase * mult);

    await c.query("update engagement set free_spins = free_spins - 1, updated_at = now() where user_id = $1", [userId]);

    let balance: number | null = null;
    if (win > 0) {
      const results = await postManyIn(c, userId, [
        {
          amount: win,
          reason: "freespin_win",
          idempotencyKey: `spin:${userId}:${Date.now()}:${randomInt(1_000_000)}`,
          refType: "spin",
        },
      ]);
      balance = results[0]!.balance;
    }
    await addXpIn(c, userId, 4);
    await bumpChallengeIn(c, userId, "spins");

    return { win, stakeBase, mult, freeSpinsLeft: row.free_spins - 1, balance };
  });
}

// --- Daily Challenges: Fortschritt aus server-sichtbaren Events -----------------

/**
 * Challenge-Fortschritt verbuchen (in bestehender Tx, users-Sperre muss gehalten
 * werden). Abschluss zahlt die level-skalierte Belohnung + 1 Freispiel; sind alle
 * vier geschafft, kommt der Tages-Chest (+2 Freispiele, +30 XP) obendrauf.
 */
export async function bumpChallengeIn(c: Client, userId: string, id: ChallengeId, n = 1): Promise<void> {
  const row = await lockEngagement(c, userId);
  const level = levelFromXp(row.xp);
  const day = utcDayNum();
  const ch: Required<ChallengeState> =
    row.challenges?.day === day
      ? { day, vals: { ...(row.challenges.vals ?? {}) }, done: { ...(row.challenges.done ?? {}) }, chestDone: row.challenges.chestDone === true }
      : { day, vals: {}, done: {}, chestDone: false };

  ch.vals[id] = (ch.vals[id] ?? 0) + n;

  let spinsPlus = 0;
  const posts: PostSpec[] = [];
  for (const def of CHALLENGE_DEFS) {
    if (!ch.done[def.id] && (ch.vals[def.id] ?? 0) >= def.target) {
      ch.done[def.id] = true;
      spinsPlus += 1;
      posts.push({
        amount: scaledForLevel(def.coins, level),
        reason: "challenge",
        idempotencyKey: `challenge:${userId}:${day}:${def.id}`, // je Tag genau einmal
        refType: "challenge",
        refId: def.id,
      });
    }
  }
  let chestXp = false;
  if (!ch.chestDone && CHALLENGE_DEFS.every((d) => ch.done[d.id])) {
    ch.chestDone = true;
    spinsPlus += 2;
    chestXp = true;
    posts.push({
      amount: scaledForLevel(CHEST_COINS, level),
      reason: "chest",
      idempotencyKey: `chest:${userId}:${day}`,
      refType: "chest",
      refId: String(day),
    });
  }

  await c.query(
    "update engagement set challenges = $2, free_spins = free_spins + $3, updated_at = now() where user_id = $1",
    [userId, JSON.stringify(ch), spinsPlus],
  );
  if (posts.length) await postManyIn(c, userId, posts);
  if (chestXp) await addXpIn(c, userId, 30);
}

// --- Stadion: Meta-Sink, boostet den Arena Bonus --------------------------------

export class StadiumError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = "StadiumError";
  }
}

export async function upgradeStadium(
  userId: string,
  part: string,
): Promise<{ part: string; level: number; cost: number; balance: number }> {
  if (!(STADIUM_PARTS as readonly string[]).includes(part)) {
    throw new StadiumError("unknown_part", `Unbekannter Ausbau: ${part}`);
  }
  return withTx(async (c) => {
    await c.query("select id from users where id = $1 for update", [userId]);
    const row = await lockEngagement(c, userId);
    const current = row.stadium?.[part] ?? 0;
    if (current >= STADIUM_MAX_LEVEL) throw new StadiumError("max_level", "Bereits Maximalstufe");
    const cost = stadiumCost(current);

    const results = await postManyIn(c, userId, [
      {
        amount: -cost,
        reason: "stadium",
        idempotencyKey: `stadium:${userId}:${part}:${current + 1}`, // je Stufe genau einmal
        refType: "stadium",
        refId: part,
      },
    ]);

    const stadium = { ...(row.stadium ?? {}), [part]: current + 1 };
    await c.query("update engagement set stadium = $2, updated_at = now() where user_id = $1", [
      userId,
      JSON.stringify(stadium),
    ]);
    await addXpIn(c, userId, 15);

    return { part, level: current + 1, cost, balance: results[0]!.balance };
  });
}

// --- Tages-Tipp: 1× täglich gratis auf die aktuelle Liga-Runde -------------------

export class TippError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = "TippError";
  }
}

export async function placeDailyPick(
  userId: string,
  choice: "1" | "X" | "2",
): Promise<{ matchId: string; choice: string; streak: number }> {
  if (!["1", "X", "2"].includes(choice)) throw new TippError("bad_choice", "Tipp muss 1, X oder 2 sein");
  return withTx(async (c) => {
    await c.query("select id from users where id = $1 for update", [userId]);
    const row = await lockEngagement(c, userId);
    const day = utcDayNum();
    if (row.pick_day === day) throw new TippError("already_picked", "Tages-Tipp heute schon abgegeben");

    // Aktuelle Liga-Runde mit offenem Wettfenster (Kickoff in der Zukunft).
    const { rows } = await c.query<{ id: string }>(
      `select m.id from matches m join league_rounds r on r.match_id = m.id
       where m.status = 'scheduled' and not r.settled and m.kickoff > now()
       order by m.kickoff asc limit 1`,
    );
    if (!rows[0]) throw new TippError("no_round", "Gerade keine offene Liga-Runde — gleich wieder");

    await c.query(
      "update engagement set pick_day = $2, pick_match = $3, pick_choice = $4, updated_at = now() where user_id = $1",
      [userId, day, rows[0].id, choice],
    );
    return { matchId: rows[0].id, choice, streak: row.pick_streak };
  });
}

/**
 * Tages-Tipps einer abgerechneten Liga-Runde auflösen (vom Liga-Settlement gerufen).
 * Treffer: Serie +1 und level-skalierte Belohnung 40 × min(Serie, 10); daneben 25 XP
 * fürs Mitmachen. Fehltipp: Serie reißt. Idempotent über den Ledger-Key.
 */
export async function resolveDailyPicks(matchId: string, home: number, away: number): Promise<number> {
  const winning = home > away ? "1" : home < away ? "2" : "X";
  const { rows } = await pool.query<{ user_id: string }>(
    "select user_id from engagement where pick_match = $1",
    [matchId],
  );
  for (const r of rows) {
    await withTx(async (c) => {
      await c.query("select id from users where id = $1 for update", [r.user_id]);
      const row = await lockEngagement(c, r.user_id);
      if (row.pick_match !== matchId) return; // Race: schon aufgelöst
      const hit = row.pick_choice === winning;
      const streak = hit ? row.pick_streak + 1 : 0;
      await c.query(
        `update engagement set pick_match = null, pick_choice = null,
           pick_streak = $2, pick_best = greatest(pick_best, $2), updated_at = now()
         where user_id = $1`,
        [r.user_id, streak],
      );
      if (hit) {
        const level = levelFromXp(row.xp);
        await postManyIn(c, r.user_id, [
          {
            amount: scaledForLevel(40 * Math.min(streak, 10), level),
            reason: "tipp",
            idempotencyKey: `tipp:${r.user_id}:${row.pick_day}`,
            refType: "tipp",
            refId: matchId,
          },
        ]);
      }
      await addXpIn(c, r.user_id, 25);
    });
  }
  return rows.length;
}
