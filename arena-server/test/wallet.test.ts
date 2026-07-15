import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { migrate, pool } from "../src/db.js";
import { getBalance, post, postMany, InsufficientFundsError } from "../src/wallet.js";
import { createGuest, signInWithApple, verifySession } from "../src/auth.js";

before(async () => {
  await migrate();
});
after(async () => {
  await pool.end();
});

/** Frisches, leeres Konto für einen Test anlegen (ohne Willkommensbonus). */
async function freshUser(): Promise<string> {
  const { rows } = await pool.query<{ id: string }>("insert into users (kind) values ('guest') returning id");
  return rows[0]!.id;
}

test("Gutschrift und Belastung verändern den Saldo korrekt", async () => {
  const u = await freshUser();
  assert.equal(await getBalance(u), 0);

  await post(u, { amount: 1000, reason: "signup_bonus", idempotencyKey: `${u}:a` });
  assert.equal(await getBalance(u), 1000);

  const r = await post(u, { amount: -300, reason: "bet_stake", idempotencyKey: `${u}:b` });
  assert.equal(r.balance, 700);
  assert.equal(await getBalance(u), 700);
});

test("Idempotenz: gleicher Key wird nicht doppelt gebucht", async () => {
  const u = await freshUser();
  const first = await post(u, { amount: 1000, reason: "signup_bonus", idempotencyKey: `${u}:once` });
  const second = await post(u, { amount: 1000, reason: "signup_bonus", idempotencyKey: `${u}:once` });

  assert.equal(first.duplicate, false);
  assert.equal(second.duplicate, true);
  assert.equal(await getBalance(u), 1000); // nur einmal wirksam
});

test("Belastung über den Saldo hinaus wirft und lässt den Saldo unverändert", async () => {
  const u = await freshUser();
  await post(u, { amount: 500, reason: "signup_bonus", idempotencyKey: `${u}:seed` });

  await assert.rejects(
    () => post(u, { amount: -600, reason: "bet_stake", idempotencyKey: `${u}:over` }),
    InsufficientFundsError,
  );
  assert.equal(await getBalance(u), 500);
});

test("postMany ist atomar: schlägt eine Buchung fehl, wird alles zurückgerollt", async () => {
  const u = await freshUser();
  await post(u, { amount: 1000, reason: "signup_bonus", idempotencyKey: `${u}:seed` });

  await assert.rejects(
    () =>
      postMany(u, [
        { amount: 500, reason: "bonus_claim", idempotencyKey: `${u}:m1` },
        { amount: -2000, reason: "bet_stake", idempotencyKey: `${u}:m2` }, // überzieht → alles rollt zurück
      ]),
    InsufficientFundsError,
  );
  assert.equal(await getBalance(u), 1000);
  // Auch der (in derselben Tx eingefügte) erste Key darf NICHT persistiert sein → Retry möglich.
  const check = await pool.query("select 1 from ledger_entries where idempotency_key = $1", [`${u}:m1`]);
  assert.equal(check.rowCount, 0);
});

test("Nebenläufigkeit: 30 parallele Belastungen können den Saldo nie negativ machen", async () => {
  const u = await freshUser();
  await post(u, { amount: 1000, reason: "signup_bonus", idempotencyKey: `${u}:seed` });

  // 30 gleichzeitige Belastungen à 100 – genau 10 dürfen durchgehen.
  const attempts = Array.from({ length: 30 }, (_, i) =>
    post(u, { amount: -100, reason: "bet_stake", idempotencyKey: `${u}:c${i}` }),
  );
  const settled = await Promise.allSettled(attempts);
  const ok = settled.filter((s) => s.status === "fulfilled").length;
  const rejected = settled.filter((s) => s.status === "rejected").length;

  assert.equal(ok, 10);
  assert.equal(rejected, 20);
  assert.equal(await getBalance(u), 0); // exakt aufgebraucht, nie negativ
});

test("Gast-Login schreibt Willkommensbonus gut", async () => {
  const s = await createGuest();
  assert.equal(s.kind, "guest");
  assert.equal(await getBalance(s.userId), 1000);

  const { userId } = await verifySession(s.token);
  assert.equal(userId, s.userId);
});

test("Sign in with Apple migriert das Gast-Konto samt Coin-Stand", async () => {
  const guest = await createGuest();
  // Etwas Aktivität auf dem Gast-Konto, damit der Saldo ≠ Startwert ist.
  await post(guest.userId, { amount: 250, reason: "bonus_claim", idempotencyKey: `${guest.userId}:x` });
  assert.equal(await getBalance(guest.userId), 1250);

  const fakeVerifier = async () => ({ sub: `apple-sub-${guest.userId}` });
  const apple = await signInWithApple("dummy-token", guest.token, fakeVerifier);

  assert.equal(apple.userId, guest.userId); // gleiches Konto, migriert
  assert.equal(apple.kind, "apple");
  assert.equal(await getBalance(apple.userId), 1250); // Coin-Stand erhalten

  // Erneuter Apple-Login (ohne Gast-Token) trifft dasselbe Konto.
  const again = await signInWithApple("dummy-token", undefined, fakeVerifier);
  assert.equal(again.userId, guest.userId);
});
