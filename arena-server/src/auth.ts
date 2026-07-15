import { SignJWT, jwtVerify, createRemoteJWKSet, type JWTPayload } from "jose";
import type { Client } from "./db.js";
import { pool, withTx } from "./db.js";
import { config } from "./config.js";
import { post } from "./wallet.js";

// ---------------------------------------------------------------------------
// Auth: Gast-Konten + Sign in with Apple. Eigene Session-Tokens (HS256).
// ---------------------------------------------------------------------------

const secret = new TextEncoder().encode(config.jwtSecret);

export interface Session {
  token: string;
  userId: string;
  kind: "guest" | "apple";
}

/** Eigenes Session-Token ausstellen. */
export async function issueSession(userId: string, kind: "guest" | "apple"): Promise<Session> {
  const token = await new SignJWT({ kind })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuer(config.jwtIssuer)
    .setIssuedAt()
    .setExpirationTime(`${config.jwtTtlSeconds}s`)
    .sign(secret);
  return { token, userId, kind };
}

/** Eigenes Session-Token prüfen → userId. Wirft bei Ungültigkeit. */
export async function verifySession(token: string): Promise<{ userId: string; kind: string }> {
  const { payload } = await jwtVerify(token, secret, { issuer: config.jwtIssuer });
  if (!payload.sub) throw new Error("Token ohne sub");
  return { userId: payload.sub, kind: String(payload.kind ?? "guest") };
}

/** Neues Gast-Konto anlegen und Willkommensguthaben idempotent gutschreiben. */
export async function createGuest(): Promise<Session> {
  const userId = await withTx(async (c) => {
    const { rows } = await c.query<{ id: string }>(
      "insert into users (kind) values ('guest') returning id",
    );
    return rows[0]!.id;
  });
  await grantSignupBonus(userId);
  return issueSession(userId, "guest");
}

async function grantSignupBonus(userId: string): Promise<void> {
  if (config.signupBonusCoins <= 0) return;
  await post(userId, {
    amount: config.signupBonusCoins,
    reason: "signup_bonus",
    idempotencyKey: `signup:${userId}`, // pro Konto genau einmal
  });
}

// Apples öffentliche Schlüssel (JWKS) – Remote-Set cacht selbstständig.
const appleJwks = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

export type AppleVerifier = (identityToken: string) => Promise<{ sub: string; email?: string }>;

/** Standard-Verifier: Apple-Identity-Token gegen Apples JWKS prüfen. */
export const verifyAppleIdentityToken: AppleVerifier = async (identityToken) => {
  const { payload }: { payload: JWTPayload } = await jwtVerify(identityToken, appleJwks, {
    issuer: "https://appleid.apple.com",
    audience: config.appleClientId,
  });
  if (!payload.sub) throw new Error("Apple-Token ohne sub");
  return { sub: payload.sub, email: typeof payload.email === "string" ? payload.email : undefined };
};

/**
 * Sign in with Apple. Optionales `guestToken` migriert ein bestehendes Gast-Konto
 * (samt Coin-Stand) auf den Apple-Account, statt ein zweites Konto anzulegen.
 * `verifier` ist injizierbar (Tests) – Standard prüft echt gegen Apple.
 */
export async function signInWithApple(
  identityToken: string,
  guestToken?: string,
  verifier: AppleVerifier = verifyAppleIdentityToken,
): Promise<Session> {
  const { sub } = await verifier(identityToken);

  const { userId, created } = await withTx(async (c) => {
    const existing = await c.query<{ id: string }>("select id from users where apple_sub = $1", [sub]);
    if (existing.rowCount && existing.rows[0]) return { userId: existing.rows[0].id, created: false };

    // Gast → Apple migrieren, falls ein gültiges Gast-Token mitgegeben wurde.
    if (guestToken) {
      const migrated = await tryMigrateGuest(c, guestToken, sub);
      if (migrated) return { userId: migrated, created: false };
    }

    const insert = await c.query<{ id: string }>(
      "insert into users (kind, apple_sub) values ('apple', $1) returning id",
      [sub],
    );
    return { userId: insert.rows[0]!.id, created: true };
  });

  // Auch ein DIREKT per Apple angelegtes Konto startet mit dem Willkommensbonus
  // (Review-Finding: sonst 0 statt 1.000 Coins). Idempotent über `signup:<userId>`.
  if (created) await grantSignupBonus(userId);

  return issueSession(userId, "apple");
}

async function tryMigrateGuest(c: Client, guestToken: string, appleSub: string): Promise<string | null> {
  let guestId: string;
  try {
    ({ userId: guestId } = await verifySession(guestToken));
  } catch {
    return null; // ungültiges Gast-Token → ignorieren, normaler Apple-Login
  }
  const upd = await c.query(
    "update users set kind = 'apple', apple_sub = $1, updated_at = now() where id = $2 and kind = 'guest' returning id",
    [appleSub, guestId],
  );
  return upd.rowCount ? guestId : null;
}
