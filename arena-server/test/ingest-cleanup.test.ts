// Regressionstests für die Review-Findings der Feed-Umstellung (15.07.2026):
// (1) Kickoff-Datum-Drift erzeugt neue Match-IDs → alte Zeile muss annulliert
//     werden (sonst wettbares Duplikat mit eingefrorenen Quoten).
// (2) Aus dem Feed verschwundene Outrights müssen gelöscht werden (sonst bleibt
//     ein ausgeschiedenes Team als "Favorit" gelistet — real passiert: Frankreich).
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { migrate, pool } from "../src/db.js";
import { getBalance, post } from "../src/wallet.js";
import { ingestOdds, listOutrights, type FeedMatch } from "../src/odds-ingest.js";
import { placeBet } from "../src/bets.js";
import { xpNeeded } from "../src/engagement.js";

before(async () => {
  await migrate();
});
after(async () => {
  await pool.end();
});

const RUN = randomUUID().slice(0, 8);
const SEED_XP = Array.from({ length: 59 }, (_, i) => xpNeeded(i + 1)).reduce((a, b) => a + b, 0);

async function fundedUser(coins = 10_000): Promise<string> {
  const { rows } = await pool.query<{ id: string }>("insert into users (kind) values ('guest') returning id");
  const id = rows[0]!.id;
  await post(id, { amount: coins, reason: "signup_bonus", idempotencyKey: `ic-seed:${id}` });
  await pool.query("insert into engagement (user_id, xp) values ($1, $2) on conflict (user_id) do update set xp = $2", [id, SEED_XP]);
  return id;
}

const hours = (h: number) => new Date(Date.now() + h * 3600_000).toISOString();

function feedMatch(id: string, kickoff: string): FeedMatch {
  return { id, home: `H-${id}`, away: `G-${id}`, kickoff, odds1x2: { "1": 2.0, X: 3.4, "2": 3.8 }, ou25: { over: 1.9, under: 1.9 } };
}

async function ingestBatch(comp: string, matches: FeedMatch[], outrights: Array<{ team: string; odds: number }> = []) {
  return ingestOdds({ competitions: [{ id: comp, name: "Cleanup-Liga", matches, outrights }] });
}

test("ID-Drift: verschobenes Spiel wird annulliert, Einsatz fließt zurück; neues Duplikat bleibt wettbar", async () => {
  const comp = `ic-${RUN}-drift`;
  const u = await fundedUser();

  // Erst-Ingest: Spiel A (Sa) + Horizont-Spiel H (So).
  await ingestBatch(comp, [feedMatch(`${comp}-A`, hours(48)), feedMatch(`${comp}-H`, hours(72))]);
  await placeBet(u, 500, [{ matchId: `${comp}-A`, market: "1X2", pick: "1" }], `ic:${RUN}:drift`);
  assert.equal(await getBalance(u), 9_500);

  // Feed-Update: dasselbe Fixture wurde auf So verschoben → NEUE ID B; A fehlt.
  const r = await ingestBatch(comp, [feedMatch(`${comp}-B`, hours(49)), feedMatch(`${comp}-H`, hours(72))]);
  assert.equal(r.voidedVanished, 1);

  const a = (await pool.query("select status from matches where id = $1", [`${comp}-A`])).rows[0];
  assert.equal(a.status, "void"); // kein wettbares Duplikat mehr
  assert.equal(await getBalance(u), 10_000); // Einsatz erstattet
  const b = (await pool.query("select status from matches where id = $1", [`${comp}-B`])).rows[0];
  assert.equal(b.status, "scheduled");
  const h = (await pool.query("select status from matches where id = $1", [`${comp}-H`])).rows[0];
  assert.equal(h.status, "scheduled"); // Horizont-Spiel unangetastet
});

test("ID-Drift: Spiele JENSEITS des Feed-Horizonts werden nicht angefasst", async () => {
  const comp = `ic-${RUN}-horizon`;
  await ingestBatch(comp, [feedMatch(`${comp}-Z`, hours(240))]); // in 10 Tagen
  // Neuer Feed deckt nur die nächsten 24 h ab — Z liegt dahinter, fehlt aber im Feed.
  const r = await ingestBatch(comp, [feedMatch(`${comp}-X`, hours(24))]);
  assert.equal(r.voidedVanished, 0);
  const z = (await pool.query("select status from matches where id = $1", [`${comp}-Z`])).rows[0];
  assert.equal(z.status, "scheduled");
});

test("Outright-Cleanup: ausgeschiedenes Team verschwindet; leeres Outright-Feld wischt nichts weg", async () => {
  const comp = `ic-${RUN}-out`;
  await ingestBatch(comp, [], [{ team: "Frankreich", odds: 2.5 }, { team: "Spanien", odds: 3.1 }]);

  // Frankreich scheidet aus → Feed listet nur noch Spanien.
  const r = await ingestBatch(comp, [], [{ team: "Spanien", odds: 1.6 }]);
  assert.equal(r.outrightsRemoved, 1);
  let rows = (await listOutrights()).filter((o) => o.competitionId === comp);
  assert.deepEqual(rows.map((o) => o.team), ["Spanien"]);
  assert.equal(rows[0]!.odds, 1.6);

  // Transient leeres Outright-Feld darf den Bestand NICHT löschen.
  const r2 = await ingestBatch(comp, [], []);
  assert.equal(r2.outrightsRemoved, 0);
  rows = (await listOutrights()).filter((o) => o.competitionId === comp);
  assert.equal(rows.length, 1);
});
