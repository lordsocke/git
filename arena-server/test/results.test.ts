// Tests der Ergebnis-Zwischenlösung (B4-Übergang): Matching + Auto-Settlement.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { migrate, pool } from "../src/db.js";
import { post, getBalance } from "../src/wallet.js";
import { placeBet } from "../src/bets.js";
import { normalizeTeam, settleFromProviders, type ProviderResult } from "../src/results.js";
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
  await post(id, { amount: coins, reason: "signup_bonus", idempotencyKey: `res-seed:${id}` });
  await pool.query("insert into engagement (user_id, xp) values ($1, $2) on conflict (user_id) do update set xp = $2", [id, SEED_XP]);
  return id;
}

test("normalizeTeam: Füllwörter, Diakritika und Großschreibung fallen weg", () => {
  assert.equal(normalizeTeam("FC Bayern München"), normalizeTeam("Bayern München"));
  assert.equal(normalizeTeam("1. FC Köln"), normalizeTeam("Köln"));
  assert.ok(normalizeTeam("Borussia Dortmund") !== normalizeTeam("Borussia Mönchengladbach"));
});

test("settleFromProviders: matcht per Teamnamen + Kickoff und rechnet über die Settlement-Engine ab", async () => {
  const u = await fundedUser();
  const kickoff = new Date(Date.now() - 3 * 3600 * 1000); // vor 3 h angepfiffen

  // Überfälliges Spiel mit zukünftigem Kickoff anlegen (für die Platzierung) …
  const id = `res-${RUN}-1`;
  await pool.query(
    `insert into matches (id, competition_id, competition_name, home, away, kickoff, odds)
     values ($1, 'wm', 'WM 2026', 'Frankreich', 'Spanien', now() + interval '1 hour', '{"1X2":{"1":2.3,"X":3.25,"2":3.31}}')`,
    [id],
  );
  const bet = await placeBet(u, 100, [{ matchId: id, market: "1X2", pick: "1" }], `res:${RUN}`);
  // … dann Kickoff in die Vergangenheit schieben (Spiel „ist gelaufen").
  await pool.query("update matches set kickoff = $2 where id = $1", [id, kickoff.toISOString()]);

  // Fixture-Provider: Namen leicht abweichend + Kickoff 1 h daneben → muss trotzdem matchen.
  const fixture: ProviderResult[] = [
    { home: "Frankreich", away: "Spanien", goalsHome: 2, goalsAway: 0, kickoff: new Date(kickoff.getTime() + 3600_000).toISOString() },
  ];
  const settled = await settleFromProviders(async (comp) => (comp === "wm" ? fixture : []));
  assert.equal(settled, 1);

  const m = (await pool.query("select status, result_home, result_away from matches where id = $1", [id])).rows[0];
  assert.equal(m.status, "finished");
  assert.equal(m.result_home, 2);

  const b = (await pool.query("select status, payout from bets where id = $1", [bet.id])).rows[0];
  assert.equal(b.status, "won");
  assert.equal(b.payout, 230);
  assert.equal(await getBalance(u), 10_000 - 100 + 230);

  // Idempotent: zweiter Lauf ändert nichts.
  const again = await settleFromProviders(async (comp) => (comp === "wm" ? fixture : []));
  assert.equal(again, 0);
});

test("settleFromProviders: kein Match (falsche Namen/Zeit) → Spiel bleibt offen für den Auto-Void", async () => {
  const id = `res-${RUN}-2`;
  await pool.query(
    `insert into matches (id, competition_id, competition_name, home, away, kickoff, odds)
     values ($1, 'pl', 'Premier League', 'Arsenal', 'Chelsea', now() - interval '4 hours', '{"1X2":{"1":2.0,"X":3.4,"2":3.6}}')`,
    [id],
  );
  const fixture: ProviderResult[] = [
    { home: "Liverpool", away: "Everton", goalsHome: 1, goalsAway: 1, kickoff: new Date().toISOString() },
  ];
  await settleFromProviders(async () => fixture);
  const m = (await pool.query("select status from matches where id = $1", [id])).rows[0];
  assert.equal(m.status, "scheduled"); // ehrlich offen — 48h-Auto-Void erstattet später
});
