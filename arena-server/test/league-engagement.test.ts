// Tests für B5 (ARENA-Liga-Engine) und B7-Kern (Engagement: XP/Level/Bonus/Spins).
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { migrate, pool } from "../src/db.js";
import { getBalance, post } from "../src/wallet.js";
import { placeBet, PlacementError } from "../src/bets.js";
import {
  ensureLeagueRound,
  currentRound,
  settleDueLeagueRounds,
  sampleResult,
  priceMarkets,
} from "../src/league.js";
import {
  getEngagement,
  claimBonus,
  playSpin,
  upgradeStadium,
  placeDailyPick,
  ClaimNotReadyError,
  NoSpinsError,
  StadiumError,
  TippError,
  xpNeeded,
  levelFromXp,
  maxStakeFor,
  bonusBase,
  WHEEL_SEGMENTS,
} from "../src/engagement.js";

before(async () => {
  await migrate();
});
after(async () => {
  await pool.end();
});

async function newUser(coins = 1_000): Promise<string> {
  const { rows } = await pool.query<{ id: string }>("insert into users (kind) values ('guest') returning id");
  const id = rows[0]!.id;
  if (coins > 0) await post(id, { amount: coins, reason: "signup_bonus", idempotencyKey: `le-seed:${id}` });
  return id;
}

/** Runde mit OFFENEM Wettfenster garantieren: Reste früherer Testläufe, deren
 * Kickoff schon vorbei ist, erst abrechnen (in Produktion erledigt das der Tick). */
async function freshRound() {
  await pool.query(
    `update league_rounds set settle_at = now() - interval '1 second'
     where not settled and match_id in (select id from matches where kickoff <= now() and status = 'scheduled')`,
  );
  await settleDueLeagueRounds();
  return ensureLeagueRound();
}

// ---------------------------------------------------------------------------
// Ökonomie-Formeln (Parität mit App/Sim)
// ---------------------------------------------------------------------------

test("Formeln: Level-Kurve, Bonus-Basis und Max-Einsatz entsprechen der App-Ökonomie", () => {
  assert.equal(xpNeeded(1), 70);
  assert.equal(levelFromXp(0), 1);
  assert.equal(levelFromXp(70), 2);
  assert.equal(bonusBase(1), 60);
  assert.equal(bonusBase(2), Math.round(60 * 1.11));
  assert.equal(maxStakeFor(1), 40);
  // Cap: Level > 55 wächst nicht weiter
  assert.equal(maxStakeFor(55), maxStakeFor(90));
  // Rad: Coin-EV ≈ 3,05 (exakt die App-Segmente)
  const w = WHEEL_SEGMENTS.reduce((s, x) => s + x.weight, 0);
  const ev = WHEEL_SEGMENTS.reduce((s, x) => s + x.coinMult * x.weight, 0) / w;
  assert.ok(Math.abs(ev - 3.05) < 0.02, `Rad-EV ${ev}`);
});

test("Liga-Pricing: Overround ≈ 8,1 % (Auszahlungsfaktor 0,925) je Markt", () => {
  const odds = priceMarkets(0.53);
  const m1x2 = odds["1X2"]!;
  const over1 = 1 / m1x2["1"]! + 1 / m1x2.X! + 1 / m1x2["2"]!;
  assert.ok(Math.abs(over1 - 1 / 0.925) < 0.02, `1X2-Overround ${over1}`);
  const ou = odds.OU25!;
  const over2 = 1 / ou.over! + 1 / ou.under!;
  assert.ok(Math.abs(over2 - 1 / 0.925) < 0.02, `OU25-Overround ${over2}`);
});

test("Liga-Ergebnis: deterministisch aus Seed (Audit/Replay)", () => {
  const a = sampleResult(12345, 0.6, 2.685);
  const b = sampleResult(12345, 0.6, 2.685);
  assert.deepEqual(a, b);
  assert.ok(a.home >= 0 && a.home < 15 && a.away >= 0 && a.away < 15);
});

// ---------------------------------------------------------------------------
// Liga-Lebenszyklus
// ---------------------------------------------------------------------------

test("Liga: Runde entsteht, Wette läuft über die normale Bet-Maschinerie, Settlement zahlt korrekt", async () => {
  const u = await newUser(1_000);
  const round = await freshRound();
  assert.ok(round.odds["1X2"]);

  // Wette auf die virtuelle Runde – gleicher Endpunkt/Service wie echte Spiele.
  // Nebenbei erfüllt die Liga-Wette sofort die "virt"-Challenge (Ziel 1) → +35 (L1).
  const bet = await placeBet(u, 40, [{ matchId: round.matchId, market: "1X2", pick: "1" }], `le:${round.matchId}:${u}`);
  assert.equal(bet.status, "open");
  const CH_VIRT = 35;
  const afterBet = 1_000 - 40 + CH_VIRT;
  assert.equal(await getBalance(u), afterBet);

  // Runde künstlich fällig machen und abrechnen.
  await pool.query("update league_rounds set settle_at = now() - interval '1 second' where match_id = $1", [round.matchId]);
  const settled = await settleDueLeagueRounds();
  assert.ok(settled >= 1);

  const m = (await pool.query("select status, result_home, result_away from matches where id = $1", [round.matchId])).rows[0];
  assert.equal(m.status, "finished");

  const b = (await pool.query("select status, payout, stake, total_odds from bets where id = $1", [bet.id])).rows[0];
  assert.notEqual(b.status, "open");
  if (b.status === "won") {
    assert.equal(b.payout, Math.round(40 * Number(b.total_odds)));
    assert.equal(await getBalance(u), afterBet + b.payout);
  } else {
    assert.equal(await getBalance(u), afterBet);
  }

  // Ergebnis stimmt mit dem deterministischen Seed-Replay überein (Audit).
  const audit = (await pool.query("select seed, q, lambda from league_rounds where match_id = $1", [round.matchId])).rows[0];
  const replay = sampleResult(Number(audit.seed), Number(audit.q), Number(audit.lambda));
  assert.equal(m.result_home, replay.home);
  assert.equal(m.result_away, replay.away);
});

test("Liga: settleDueLeagueRounds ist idempotent, currentRound liefert nach Settlement die nächste Runde", async () => {
  const before = await currentRound();
  if (before) {
    await pool.query("update league_rounds set settle_at = now() - interval '1 second' where match_id = $1", [before.matchId]);
    await settleDueLeagueRounds();
  }
  const again = await settleDueLeagueRounds(); // nichts mehr fällig
  assert.equal(again, 0);
  const next = await ensureLeagueRound();
  assert.notEqual(next.matchId, before?.matchId);
});

// ---------------------------------------------------------------------------
// Engagement: Bonus, Rad, Spins, Level-Cap
// ---------------------------------------------------------------------------

test("Engagement: Default-Zustand (Level 1, 2 Freispiele, Max-Einsatz 40)", async () => {
  const u = await newUser();
  const e = await getEngagement(u);
  assert.equal(e.level, 1);
  assert.equal(e.freeSpins, 2);
  assert.equal(e.maxStake, 40);
  assert.equal(e.bonusReadyAt, null);
});

test("Engagement: Bonus-Claim zahlt level-basiert, setzt 3h-Timer, zweiter Claim scheitert", async () => {
  const u = await newUser();
  const r = await claimBonus(u);
  assert.equal(r.amount, Math.round(60 * 1.07)); // L1-Basis × Serie-Tag-1 (1,07)
  assert.equal(r.wheel, null); // erst der 3. Claim dreht das Rad
  assert.equal(await getBalance(u), 1_000 + r.amount);

  const e = await getEngagement(u);
  assert.equal(e.ring, 1);
  assert.equal(e.freeSpins, 4); // 2 Start + 2 aus dem Claim
  assert.ok(e.bonusReadyAt !== null);

  await assert.rejects(() => claimBonus(u), ClaimNotReadyError);
});

test("Engagement: der 3. Claim dreht das Rad (Coins/Spins/Karten) und setzt den Ring zurück", async () => {
  const u = await newUser();
  for (let i = 0; i < 2; i++) {
    await claimBonus(u);
    await pool.query("update engagement set bonus_ready_at = null where user_id = $1", [u]);
  }
  const third = await claimBonus(u);
  assert.ok(third.wheel, "3. Claim muss das Rad drehen");
  const seg = third.wheel!;
  assert.ok(seg.coinWin > 0 || seg.freeSpins > 0 || seg.cards > 0);
  if (seg.coinWin > 0) {
    const entry = await pool.query(
      "select count(*)::int as n from ledger_entries where account_id = $1 and reason = 'wheel'",
      [u],
    );
    assert.equal(entry.rows[0].n, 1);
  }
  assert.equal((await getEngagement(u)).ring, 0);
});

test("Engagement: Freispiele werden verbraucht, Gewinne über das Ledger gutgeschrieben", async () => {
  const u = await newUser();
  const start = await getBalance(u);
  let spins = (await getEngagement(u)).freeSpins;
  let totalWin = 0;
  while (spins > 0) {
    const r = await playSpin(u);
    totalWin += r.win;
    spins = r.freeSpinsLeft;
  }
  assert.equal(await getBalance(u), start + totalWin);
  await assert.rejects(() => playSpin(u), NoSpinsError);
});

test("Engagement: XP aus Tipps levelt, Level-up zahlt Bonus + 3 Freispiele", async () => {
  const u = await newUser(2_000);
  // Level 2 braucht 70 XP = 7 Tipps à 10 XP.
  const round = await freshRound();
  for (let i = 0; i < 7; i++) {
    await placeBet(u, 10, [{ matchId: round.matchId, market: "1X2", pick: "1" }], `xp:${u}:${i}`);
  }
  const e = await getEngagement(u);
  assert.equal(e.level, 2);
  const lvlBonus = await pool.query(
    "select amount from ledger_entries where account_id = $1 and reason = 'levelup'",
    [u],
  );
  assert.equal(lvlBonus.rowCount, 1);
  assert.equal(lvlBonus.rows[0].amount, Math.round(300 * 1.11)); // Level-2-Bonus
  // 2 Start + 3 Level-up + 1 "virt"-Challenge (1. Liga-Wette) + 1 "bets"-Challenge (2. Tipp)
  assert.equal(e.freeSpins, 2 + 3 + 1 + 1);
  assert.equal(e.maxStake, maxStakeFor(2));
});

// ---------------------------------------------------------------------------
// B7-Rest: Challenges, Stadion, Tages-Tipp
// ---------------------------------------------------------------------------

test("Challenges: server-sichtbare Events zählen, Abschluss zahlt level-skaliert, alle 4 = Chest", async () => {
  const u = await newUser(1_000);
  const round = await freshRound();

  // 'virt' (1 Liga-Wette) + 'bets' (2 Tipps): zwei Liga-Wetten erledigen beide.
  await placeBet(u, 10, [{ matchId: round.matchId, market: "1X2", pick: "1" }], `ch:${u}:1`);
  await placeBet(u, 10, [{ matchId: round.matchId, market: "OU25", pick: "over" }], `ch:${u}:2`);
  // 'bonus' (2 Claims):
  await claimBonus(u);
  await pool.query("update engagement set bonus_ready_at = null where user_id = $1", [u]);
  await claimBonus(u);
  // 'spins' (5 Freispiele) — Spins sind durch Claims/Challenges reichlich da:
  for (let i = 0; i < 5; i++) await playSpin(u);

  const e = await getEngagement(u);
  assert.ok(e.challenges.every((c) => c.done), JSON.stringify(e.challenges));
  assert.equal(e.chestDone, true);

  const reasons = await pool.query(
    "select reason, count(*)::int as n from ledger_entries where account_id = $1 and reason in ('challenge','chest') group by reason",
    [u],
  );
  const byReason = Object.fromEntries(reasons.rows.map((r) => [r.reason, r.n]));
  assert.equal(byReason.challenge, 4);
  assert.equal(byReason.chest, 1);
});

test("Stadion: Ausbau kostet über das Ledger, boostet den Bonus, Stufen-Kauf ist idempotent", async () => {
  const u = await newUser(2_000);
  const r1 = await upgradeStadium(u, "tribune");
  assert.equal(r1.level, 1);
  assert.equal(r1.cost, 250);
  assert.equal(r1.balance, 2_000 - 250);

  const r2 = await upgradeStadium(u, "tribune"); // Stufe 2 kostet das Doppelte
  assert.equal(r2.cost, 500);

  await assert.rejects(() => upgradeStadium(u, "vipdeck"), StadiumError); // unbekannter Teil

  // Bonus-Boost: 2 Stufen = +3 % auf den Claim (Serie Tag 1: ×1,07)
  const claim = await claimBonus(u);
  assert.equal(claim.amount, Math.round(60 * Math.min(1.07 * 1.03, 2)));
});

test("Tages-Tipp: 1× täglich, Auflösung beim Liga-Settlement, Treffer zahlt Serie-Belohnung", async () => {
  const u = await newUser(1_000);
  const round = await freshRound();

  // Gewinner vorab aus dem gespeicherten Seed bestimmen → Treffer erzwingen (deterministisch).
  const audit = (await pool.query("select seed, q, lambda from league_rounds where match_id = $1", [round.matchId])).rows[0];
  const result = sampleResult(Number(audit.seed), Number(audit.q), Number(audit.lambda));
  const winning = result.home > result.away ? "1" : result.home < result.away ? "2" : "X";

  const pick = await placeDailyPick(u, winning as "1" | "X" | "2");
  assert.equal(pick.matchId, round.matchId);
  await assert.rejects(() => placeDailyPick(u, "1"), TippError); // nur 1× pro Tag

  const before = await getBalance(u);
  await pool.query("update league_rounds set settle_at = now() - interval '1 second' where match_id = $1", [round.matchId]);
  await settleDueLeagueRounds();

  const e = await getEngagement(u);
  assert.equal(e.pickStreak, 1);
  assert.equal(await getBalance(u), before + 40); // 40 × min(Serie 1, 10), Level 1
  const entry = await pool.query("select count(*)::int as n from ledger_entries where account_id = $1 and reason = 'tipp'", [u]);
  assert.equal(entry.rows[0].n, 1);
});

test("Engagement: Einsatz über dem Level-Cap wird serverseitig abgelehnt", async () => {
  const u = await newUser(5_000);
  const round = await freshRound();
  await assert.rejects(
    () => placeBet(u, 50, [{ matchId: round.matchId, market: "1X2", pick: "1" }], `cap:${u}`),
    (err: PlacementError) => err instanceof PlacementError && err.code === "stake_above_level_cap",
  );
  assert.equal(await getBalance(u), 5_000);
});
