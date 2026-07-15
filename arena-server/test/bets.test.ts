import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { migrate, pool } from "../src/db.js";
import { getBalance, post } from "../src/wallet.js";
import { ingestOdds } from "../src/odds-ingest.js";
import { placeBet, PlacementError } from "../src/bets.js";
import { recordResult, voidMatch, sweepMatch, ResultConflictError } from "../src/settlement.js";

before(async () => {
  await migrate();
});
after(async () => {
  await pool.end();
});

// ---------------------------------------------------------------------------
// Helfer
// ---------------------------------------------------------------------------

const RUN = randomUUID().slice(0, 8); // eindeutige IDs je Testlauf

// Exakt an einer Levelgrenze (L60, Rest 0): Test-XP-Zuwächse lösen nie ein
// Level-up aus (kein unerwarteter Bonus in Balance-Assertions); Cap ~150 T.
import { xpNeeded } from "../src/engagement.js";
const SEED_XP = Array.from({ length: 59 }, (_, i) => xpNeeded(i + 1)).reduce((a, b) => a + b, 0);

async function fundedUser(coins = 10_000): Promise<string> {
  const { rows } = await pool.query<{ id: string }>("insert into users (kind) values ('guest') returning id");
  const id = rows[0]!.id;
  await post(id, { amount: coins, reason: "signup_bonus", idempotencyKey: `test-seed:${id}` });
  await pool.query("insert into engagement (user_id, xp) values ($1, $2) on conflict (user_id) do update set xp = $2", [id, SEED_XP]);
  return id;
}

let matchSeq = 0;
/** Spiel über den regulären Ingest-Pfad anlegen (Kickoff in der Zukunft).
 * Eigene Competition je Spiel: die Vanish-Bereinigung des Ingests darf
 * parallel laufende Testspiele nicht als "verschwunden" annullieren. */
async function makeMatch(odds1x2 = { "1": 2.0, X: 3.4, "2": 3.8 }, ou25 = { over: 1.9, under: 1.9 }): Promise<string> {
  const id = `m-${RUN}-${++matchSeq}`;
  await ingestOdds({
    competitions: [
      {
        id: `test-${RUN}-${matchSeq}`,
        name: "Test-Liga",
        matches: [
          {
            id,
            home: `Heim${matchSeq}`,
            away: `Gast${matchSeq}`,
            kickoff: new Date(Date.now() + 3_600_000).toISOString(),
            odds1x2,
            ou25,
          },
        ],
      },
    ],
  });
  return id;
}

const key = () => `test:${randomUUID()}`;

// ---------------------------------------------------------------------------
// Ingest
// ---------------------------------------------------------------------------

test("Ingest: Quotenänderung erhöht odds_version, unveränderte Quoten nicht", async () => {
  const id = await makeMatch({ "1": 2.0, X: 3.4, "2": 3.8 });
  const v1 = (await pool.query("select odds_version from matches where id = $1", [id])).rows[0].odds_version;

  // identische Quoten erneut → Version bleibt
  await ingestOdds({
    competitions: [{ id: `test-${RUN}-x`, name: "Test-Liga", matches: [{ id, home: "A", away: "B", kickoff: new Date(Date.now() + 3_600_000).toISOString(), odds1x2: { "1": 2.0, X: 3.4, "2": 3.8 }, ou25: { over: 1.9, under: 1.9 } }] }],
  });
  const v2 = (await pool.query("select odds_version from matches where id = $1", [id])).rows[0].odds_version;
  assert.equal(v2, v1);

  // geänderte Quote → Version steigt
  await ingestOdds({
    competitions: [{ id: `test-${RUN}-x`, name: "Test-Liga", matches: [{ id, home: "A", away: "B", kickoff: new Date(Date.now() + 3_600_000).toISOString(), odds1x2: { "1": 2.1, X: 3.4, "2": 3.8 }, ou25: { over: 1.9, under: 1.9 } }] }],
  });
  const v3 = (await pool.query("select odds_version from matches where id = $1", [id])).rows[0].odds_version;
  assert.equal(v3, v1 + 1);
});

test("Ingest: abgerechnete Spiele werden nicht mehr überschrieben", async () => {
  const id = await makeMatch();
  await recordResult(id, 1, 0);
  await ingestOdds({
    competitions: [{ id: `test-${RUN}-x`, name: "Test-Liga", matches: [{ id, home: "NEU", away: "NEU", kickoff: new Date(Date.now() + 3_600_000).toISOString(), odds1x2: { "1": 9.9, X: 9.9, "2": 9.9 }, ou25: { over: 1.5, under: 2.5 } }] }],
  });
  const m = (await pool.query("select status, home from matches where id = $1", [id])).rows[0];
  assert.equal(m.status, "finished");
  assert.notEqual(m.home, "NEU");
});

// ---------------------------------------------------------------------------
// Platzierung
// ---------------------------------------------------------------------------

test("Platzierung: Einsatz wird per Ledger abgebucht, Quote kommt vom Server", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch({ "1": 2.5, X: 3.2, "2": 2.9 });

  const bet = await placeBet(u, 1_000, [{ matchId: m, market: "1X2", pick: "1" }], key());
  assert.equal(bet.status, "open");
  assert.equal(bet.stake, 1_000);
  assert.equal(bet.legs[0]!.odds, 2.5); // server-autoritativ bepreist
  assert.equal(await getBalance(u), 9_000);

  const ledger = await pool.query(
    "select reason, amount from ledger_entries where account_id = $1 order by id desc limit 1",
    [u],
  );
  assert.equal(ledger.rows[0].reason, "bet_stake");
  assert.equal(ledger.rows[0].amount, -1_000);
});

test("Platzierung: idempotent – gleicher Key liefert dieselbe Wette, bucht nie doppelt", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch();
  const k = key();

  const b1 = await placeBet(u, 500, [{ matchId: m, market: "1X2", pick: "X" }], k);
  const b2 = await placeBet(u, 500, [{ matchId: m, market: "1X2", pick: "X" }], k);
  assert.equal(b1.id, b2.id);
  assert.equal(await getBalance(u), 9_500); // nur einmal abgebucht
});

test("Platzierung: Validierungsfehler (Match, Pick, Stake, Combo, Kickoff)", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch();

  await assert.rejects(() => placeBet(u, 100, [{ matchId: "gibts-nicht", market: "1X2", pick: "1" }], key()), PlacementError);
  await assert.rejects(() => placeBet(u, 100, [{ matchId: m, market: "1X2", pick: "over" }], key()), PlacementError);
  await assert.rejects(() => placeBet(u, 5, [{ matchId: m, market: "1X2", pick: "1" }], key()), PlacementError); // < minStake
  await assert.rejects(() => placeBet(u, 100.5, [{ matchId: m, market: "1X2", pick: "1" }], key()), PlacementError); // nicht ganzzahlig
  await assert.rejects(
    () => placeBet(u, 100, [
      { matchId: m, market: "1X2", pick: "1" },
      { matchId: m, market: "1X2", pick: "X" },
    ], key()),
    PlacementError, // gleiches Spiel doppelt
  );

  // 5 Legs (> maxComboLegs 4)
  const ms = await Promise.all([makeMatch(), makeMatch(), makeMatch(), makeMatch(), makeMatch()]);
  await assert.rejects(
    () => placeBet(u, 100, ms.map((x) => ({ matchId: x, market: "1X2" as const, pick: "1" })), key()),
    PlacementError,
  );

  // Kickoff in der Vergangenheit
  const past = `m-${RUN}-past`;
  await pool.query(
    `insert into matches (id, competition_id, competition_name, home, away, kickoff, odds)
     values ($1, 'test', 'Test-Liga', 'H', 'G', now() - interval '5 minutes', '{"1X2":{"1":2.0,"X":3.0,"2":4.0}}')`,
    [past],
  );
  await assert.rejects(() => placeBet(u, 100, [{ matchId: past, market: "1X2", pick: "1" }], key()), PlacementError);

  assert.equal(await getBalance(u), 10_000); // nichts davon hat Geld bewegt
});

test("Platzierung: zu wenig Coins → Rollback, KEINE Wette bleibt zurück", async () => {
  const u = await fundedUser(100);
  const m = await makeMatch();
  const k = key();

  await assert.rejects(() => placeBet(u, 500, [{ matchId: m, market: "1X2", pick: "1" }], k));
  assert.equal(await getBalance(u), 100);
  const orphan = await pool.query("select 1 from bets where idempotency_key = $1", [k]);
  assert.equal(orphan.rowCount, 0); // Retry mit gleichem Key bleibt möglich
});

test("Platzierung: nach Abpfiff/Abrechnung geschlossen", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch();
  await recordResult(m, 2, 1);
  await assert.rejects(() => placeBet(u, 100, [{ matchId: m, market: "1X2", pick: "1" }], key()), PlacementError);
});

// ---------------------------------------------------------------------------
// Settlement
// ---------------------------------------------------------------------------

test("Settlement: Gewinn zahlt round(stake × odds) über das Ledger aus", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch({ "1": 2.35, X: 3.2, "2": 2.9 });
  const bet = await placeBet(u, 1_000, [{ matchId: m, market: "1X2", pick: "1" }], key());

  const summary = await recordResult(m, 3, 1); // Heimsieg → '1' gewinnt
  assert.equal(summary.betsSettled, 1);

  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "won");
  assert.equal(b.payout, 2_350); // round(1000 × 2,35)
  assert.equal(await getBalance(u), 9_000 + 2_350);

  const entry = await pool.query("select reason from ledger_entries where idempotency_key = $1", [`bet:${bet.id}:payout`]);
  assert.equal(entry.rows[0].reason, "bet_payout");
});

test("Settlement: Verlust zahlt nichts aus", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch();
  const bet = await placeBet(u, 1_000, [{ matchId: m, market: "1X2", pick: "1" }], key());

  await recordResult(m, 0, 2); // Auswärtssieg → '1' verliert
  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "lost");
  assert.equal(b.payout, 0);
  assert.equal(await getBalance(u), 9_000);
});

test("Settlement: OU25 – 2:1 gewinnt over, 1:1 gewinnt under", async () => {
  const u = await fundedUser(10_000);
  const m1 = await makeMatch(undefined, { over: 1.8, under: 2.0 });
  const m2 = await makeMatch(undefined, { over: 1.8, under: 2.0 });
  const over = await placeBet(u, 100, [{ matchId: m1, market: "OU25", pick: "over" }], key());
  const under = await placeBet(u, 100, [{ matchId: m2, market: "OU25", pick: "under" }], key());

  await recordResult(m1, 2, 1); // 3 Tore → over
  await recordResult(m2, 1, 1); // 2 Tore → under
  const s1 = (await pool.query("select status from bets where id = $1", [over.id])).rows[0].status;
  const s2 = (await pool.query("select status from bets where id = $1", [under.id])).rows[0].status;
  assert.equal(s1, "won");
  assert.equal(s2, "won");
});

test("Settlement: idempotent – gleiches Ergebnis doppelt zahlt nie doppelt", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch({ "1": 2.0, X: 3.0, "2": 4.0 });
  await placeBet(u, 1_000, [{ matchId: m, market: "1X2", pick: "1" }], key());

  const first = await recordResult(m, 1, 0);
  const second = await recordResult(m, 1, 0); // erneut: No-Op + Sweep
  assert.equal(first.alreadyFinished, false);
  assert.equal(second.alreadyFinished, true);
  assert.equal(second.betsSettled, 0);
  assert.equal(await getBalance(u), 9_000 + 2_000); // exakt eine Auszahlung

  await sweepMatch(m); // zusätzlicher Sweep ändert nichts
  assert.equal(await getBalance(u), 9_000 + 2_000);
});

test("Settlement: abweichendes Ergebnis für abgerechnetes Spiel → Konflikt", async () => {
  const m = await makeMatch();
  await recordResult(m, 1, 0);
  await assert.rejects(() => recordResult(m, 2, 0), ResultConflictError);
});

test("Kombi: bleibt offen bis alle Legs entschieden sind, Payout = Produkt der Quoten", async () => {
  const u = await fundedUser(10_000);
  const m1 = await makeMatch({ "1": 2.0, X: 3.0, "2": 4.0 });
  const m2 = await makeMatch({ "1": 1.5, X: 3.5, "2": 5.0 });
  const bet = await placeBet(u, 1_000, [
    { matchId: m1, market: "1X2", pick: "1" },
    { matchId: m2, market: "1X2", pick: "1" },
  ], key());

  await recordResult(m1, 1, 0); // Leg 1 gewonnen
  let b = (await pool.query("select status from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "open"); // noch nicht entscheidbar

  await recordResult(m2, 2, 0); // Leg 2 gewonnen
  b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "won");
  assert.equal(b.payout, 3_000); // 1000 × 2,0 × 1,5
  assert.equal(await getBalance(u), 9_000 + 3_000);
});

test("Kombi: ein verlorenes Leg macht die Wette verloren", async () => {
  const u = await fundedUser(10_000);
  const m1 = await makeMatch();
  const m2 = await makeMatch();
  const bet = await placeBet(u, 500, [
    { matchId: m1, market: "1X2", pick: "1" },
    { matchId: m2, market: "1X2", pick: "1" },
  ], key());

  await recordResult(m1, 0, 1); // verloren
  await recordResult(m2, 1, 0); // gewonnen – egal
  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "lost");
  assert.equal(await getBalance(u), 9_500);
});

test("Void: Einzelwette wird vollständig erstattet", async () => {
  const u = await fundedUser(10_000);
  const m = await makeMatch();
  const bet = await placeBet(u, 800, [{ matchId: m, market: "1X2", pick: "1" }], key());

  await voidMatch(m);
  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "void");
  assert.equal(b.payout, 800);
  assert.equal(await getBalance(u), 10_000); // neutral

  const entry = await pool.query("select reason from ledger_entries where idempotency_key = $1", [`bet:${bet.id}:payout`]);
  assert.equal(entry.rows[0].reason, "bet_void");
});

test("Kombi mit Void-Leg: Void zählt als Quote 1,0", async () => {
  const u = await fundedUser(10_000);
  const m1 = await makeMatch({ "1": 2.0, X: 3.0, "2": 4.0 });
  const m2 = await makeMatch();
  const bet = await placeBet(u, 1_000, [
    { matchId: m1, market: "1X2", pick: "1" },
    { matchId: m2, market: "1X2", pick: "1" },
  ], key());

  await voidMatch(m2);
  await recordResult(m1, 1, 0);
  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "won");
  assert.equal(b.payout, 2_000); // nur die gewonnene Quote zählt
});

test("Void nach regulärer Abrechnung ist unzulässig", async () => {
  const m = await makeMatch();
  await recordResult(m, 1, 1);
  await assert.rejects(() => voidMatch(m), ResultConflictError);
});
