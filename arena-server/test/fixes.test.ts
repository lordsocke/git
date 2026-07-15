// Regressionstests für die bestätigten Findings der adversarialen Review (B3).
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { migrate, pool } from "../src/db.js";
import { getBalance, post } from "../src/wallet.js";
import { ingestOdds, listOutrights } from "../src/odds-ingest.js";
import { placeBet, PlacementError } from "../src/bets.js";
import { recordResult, sweepUndecidedBets, voidStaleMatches } from "../src/settlement.js";
import { signInWithApple } from "../src/auth.js";

before(async () => {
  await migrate();
});
after(async () => {
  await pool.end();
});

const RUN = randomUUID().slice(0, 8);
let matchSeq = 0;

// Exakt an einer Levelgrenze (L60, Rest 0): Test-XP-Zuwächse lösen nie ein
// Level-up aus (kein unerwarteter Bonus in Balance-Assertions); Cap ~150 T.
import { xpNeeded } from "../src/engagement.js";
const SEED_XP = Array.from({ length: 59 }, (_, i) => xpNeeded(i + 1)).reduce((a, b) => a + b, 0);

async function fundedUser(coins = 10_000): Promise<string> {
  const { rows } = await pool.query<{ id: string }>("insert into users (kind) values ('guest') returning id");
  const id = rows[0]!.id;
  await post(id, { amount: coins, reason: "signup_bonus", idempotencyKey: `fix-seed:${id}` });
  await pool.query("insert into engagement (user_id, xp) values ($1, $2) on conflict (user_id) do update set xp = $2", [id, SEED_XP]);
  return id;
}

async function makeMatch(): Promise<string> {
  const id = `fx-${RUN}-${++matchSeq}`;
  await ingestOdds({
    competitions: [{
      id: `test-${RUN}-${matchSeq}`, name: "Test-Liga",
      matches: [{
        id, home: `H${matchSeq}`, away: `G${matchSeq}`,
        kickoff: new Date(Date.now() + 3_600_000).toISOString(),
        odds1x2: { "1": 2.0, X: 3.4, "2": 3.8 }, ou25: { over: 1.9, under: 1.9 },
      }],
    }],
  });
  return id;
}

const key = () => `fix:${randomUUID()}`;

// --- Finding: Idempotenz-Key nicht user-gebunden -----------------------------

test("Fix Idempotenz: fremder Key liefert 422 statt fremder Wette", async () => {
  const a = await fundedUser();
  const b = await fundedUser();
  const m = await makeMatch();
  const k = key();

  await placeBet(a, 500, [{ matchId: m, market: "1X2", pick: "1" }], k);
  await assert.rejects(
    () => placeBet(b, 500, [{ matchId: m, market: "1X2", pick: "1" }], k),
    (err: PlacementError) => err instanceof PlacementError && err.code === "idempotency_conflict",
  );
  assert.equal(await getBalance(b), 10_000); // bei B wurde nichts gebucht
});

test("Fix Idempotenz: gleicher Key mit ANDERER Wette liefert 422 statt stiller Alt-Wette", async () => {
  const u = await fundedUser();
  const m1 = await makeMatch();
  const m2 = await makeMatch();
  const k = key();

  await placeBet(u, 500, [{ matchId: m1, market: "1X2", pick: "1" }], k);
  // anderer Einsatz
  await assert.rejects(
    () => placeBet(u, 900, [{ matchId: m1, market: "1X2", pick: "1" }], k),
    (err: PlacementError) => err instanceof PlacementError && err.code === "idempotency_mismatch",
  );
  // andere Auswahl
  await assert.rejects(
    () => placeBet(u, 500, [{ matchId: m2, market: "1X2", pick: "1" }], k),
    (err: PlacementError) => err instanceof PlacementError && err.code === "idempotency_mismatch",
  );
  assert.equal(await getBalance(u), 9_500); // nur die erste Wette wurde gebucht
});

test("Fix Race: zwei GLEICHZEITIGE Platzierungen mit gleichem Key → beide erhalten dieselbe Wette", async () => {
  const u = await fundedUser();
  const m = await makeMatch();
  const k = key();
  const legs = [{ matchId: m, market: "1X2" as const, pick: "1" }];

  const results = await Promise.allSettled([placeBet(u, 300, legs, k), placeBet(u, 300, legs, k)]);
  const fulfilled = results.filter((r): r is PromiseFulfilledResult<Awaited<ReturnType<typeof placeBet>>> => r.status === "fulfilled");
  assert.equal(fulfilled.length, 2, `beide müssen erfolgreich sein, war: ${JSON.stringify(results.map((r) => r.status))}`);
  assert.equal(fulfilled[0]!.value.id, fulfilled[1]!.value.id);
  assert.equal(await getBalance(u), 9_700); // exakt einmal abgebucht
});

// --- Finding: verlorene Kombi hängt an offenem Spiel --------------------------

test("Fix Early-Settle: Kombi mit verlorenem Leg wird sofort abgerechnet (anderes Spiel noch offen)", async () => {
  const u = await fundedUser();
  const m1 = await makeMatch();
  const m2 = await makeMatch(); // bleibt offen
  const bet = await placeBet(u, 400, [
    { matchId: m1, market: "1X2", pick: "1" },
    { matchId: m2, market: "1X2", pick: "1" },
  ], key());

  await recordResult(m1, 0, 1); // Leg 1 verloren
  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "lost"); // NICHT mehr 'open'
  assert.equal(b.payout, 0);
});

// --- Finding: Crash-Fenster zwischen Leg-Settlement und Sweep -----------------

test("Fix Recovery-Sweep: hängende entschiedene Wette wird nachträglich ausgezahlt", async () => {
  const u = await fundedUser();
  const m = await makeMatch();
  const bet = await placeBet(u, 1_000, [{ matchId: m, market: "1X2", pick: "1" }], key());

  // Crash simulieren: Match + Legs sind entschieden, aber der Bet-Sweep lief nie.
  await pool.query("update matches set status='finished', result_home=1, result_away=0, settled_at=now() where id=$1", [m]);
  await pool.query("update bet_legs set status='won' where bet_id=$1", [bet.id]);
  assert.equal((await pool.query("select status from bets where id=$1", [bet.id])).rows[0].status, "open");

  const settled = await sweepUndecidedBets();
  assert.ok(settled >= 1);
  const b = (await pool.query("select status, payout from bets where id=$1", [bet.id])).rows[0];
  assert.equal(b.status, "won");
  assert.equal(b.payout, 2_000);
  assert.equal(await getBalance(u), 9_000 + 2_000);
});

// --- Finding: verwaiste Matches blockieren Wetten für immer -------------------

test("Fix Auto-Void: Spiel ohne Ergebnis 48h nach Kickoff wird annulliert, Einsatz fließt zurück", async () => {
  const u = await fundedUser();
  const m = await makeMatch();
  await placeBet(u, 600, [{ matchId: m, market: "1X2", pick: "1" }], key());

  // Spiel künstlich altern lassen (Kickoff vor 3 Tagen, nie ein Ergebnis gekommen).
  await pool.query("update matches set kickoff = now() - interval '3 days' where id = $1", [m]);
  const voided = await voidStaleMatches(48);
  assert.ok(voided >= 1);

  const match = (await pool.query("select status from matches where id=$1", [m])).rows[0];
  assert.equal(match.status, "void");
  assert.equal(await getBalance(u), 10_000); // vollständig erstattet
});

// --- Finding: direkter Apple-Login ohne Signup-Bonus ---------------------------

test("Fix Apple-Signup: direkter Apple-Login (ohne Gast) startet mit Willkommensbonus", async () => {
  const sub = `apple-fix-${randomUUID()}`;
  const session = await signInWithApple("fake-token", undefined, async () => ({ sub }));
  assert.equal(await getBalance(session.userId), 1_000);

  // Wiederholter Login legt kein zweites Konto an und bucht keinen zweiten Bonus.
  const again = await signInWithApple("fake-token", undefined, async () => ({ sub }));
  assert.equal(again.userId, session.userId);
  assert.equal(await getBalance(session.userId), 1_000);
});

// --- Finding: ein kaputter Feed-Datensatz bricht den Ingest ab -----------------

test("Fix Ingest-Robustheit: kaputter Datensatz stoppt die restlichen Upserts nicht", async () => {
  const good = `fx-${RUN}-good`;
  const result = await ingestOdds({
    competitions: [{
      id: `test-${RUN}-x`, name: "Test-Liga",
      matches: [
        { id: `fx-${RUN}-tbd`, home: "A", away: "B", kickoff: "TBD", odds1x2: { "1": 2, X: 3, "2": 4 } },
        // Jahr 0: von JS parsebar, von Postgres abgelehnt → DB-Fehler-Pfad
        { id: `fx-${RUN}-y0`, home: "A", away: "B", kickoff: "0000-01-01T00:00:00Z", odds1x2: { "1": 2, X: 3, "2": 4 } },
        { id: good, home: "Gut", away: "Auch", kickoff: new Date(Date.now() + 3_600_000).toISOString(), odds1x2: { "1": 2, X: 3, "2": 4 } },
      ],
    }],
  });
  assert.equal((await pool.query("select count(*)::int as n from matches where id=$1", [good])).rows[0].n, 1);
  assert.ok(result.skipped >= 1); // "TBD" am Guard gescheitert
  assert.ok(result.errors >= 1); // Jahr 0 am DB-Cast gescheitert
  assert.equal(result.upserted, 1);
});

// --- Finding: Outrights gehen verloren ----------------------------------------

test("Fix Outrights: werden ingestiert und über die API-Funktion geliefert", async () => {
  await ingestOdds({
    competitions: [{
      id: `fxcomp-${RUN}`, name: "Fix-Turnier",
      matches: [],
      outrights: [
        { team: "Frankreich", odds: 2.5 },
        { team: "Spanien", odds: 3.1 },
      ],
    }],
  });
  const rows = (await listOutrights()).filter((o) => o.competitionId === `fxcomp-${RUN}`);
  assert.equal(rows.length, 2);
  assert.equal(rows[0]!.team, "Frankreich"); // nach Quote sortiert
  assert.equal(rows[0]!.odds, 2.5);

  // Quoten-Update ändert den Wert (Upsert statt Duplikat); Spanien fehlt im
  // neuen Feed → wird entfernt (Review-Finding: ausgeschiedene Teams dürfen
  // nicht mit alter Quote als Favorit stehen bleiben).
  await ingestOdds({
    competitions: [{ id: `fxcomp-${RUN}`, name: "Fix-Turnier", matches: [], outrights: [{ team: "Frankreich", odds: 2.2 }] }],
  });
  const updated = (await listOutrights()).filter((o) => o.competitionId === `fxcomp-${RUN}`);
  assert.deepEqual(updated.map((o) => o.team), ["Frankreich"]);
  assert.equal(updated[0]!.odds, 2.2);
});
