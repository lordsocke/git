import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from "fastify";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { config } from "./config.js";
import { pool } from "./db.js";
import { createGuest, signInWithApple, verifySession, type AppleVerifier } from "./auth.js";
import { getBalance, history, post, InsufficientFundsError } from "./wallet.js";
import { placeBet, listBets, getBet, listMatches, PlacementError, type LegInput } from "./bets.js";
import { recordResult, voidMatch, MatchNotFoundError, ResultConflictError } from "./settlement.js";
import { fetchAndIngest, listOutrights } from "./odds-ingest.js";
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
} from "./engagement.js";
import { currentRound, ensureLeagueRound } from "./league.js";

declare module "fastify" {
  interface FastifyRequest {
    userId?: string;
    userKind?: string;
  }
}

export interface BuildOptions {
  // Test-Hook: Apple-Verifikation injizieren, um ohne echtes Apple-Token zu testen.
  appleVerifier?: AppleVerifier;
}

export function buildServer(opts: BuildOptions = {}): FastifyInstance {
  const app = Fastify({ logger: false });

  // --- Auth-Hook: Bearer-Token prüfen und userId setzen ---
  async function requireAuth(req: FastifyRequest, reply: FastifyReply): Promise<void> {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      await reply.code(401).send({ error: "unauthorized" });
      return;
    }
    try {
      const { userId, kind } = await verifySession(header.slice(7));
      req.userId = userId;
      req.userKind = kind;
    } catch {
      await reply.code(401).send({ error: "invalid_token" });
    }
  }

  app.get("/health", async () => {
    await pool.query("select 1");
    return { ok: true, service: "arena-server", ts: new Date().toISOString() };
  });

  // --- Auth ---
  app.post("/auth/guest", async () => {
    const session = await createGuest();
    return { ...session, balance: await getBalance(session.userId) };
  });

  app.post<{ Body: { identityToken?: string; guestToken?: string } }>("/auth/apple", async (req, reply) => {
    const { identityToken, guestToken } = req.body ?? {};
    if (!identityToken) return reply.code(400).send({ error: "identityToken erforderlich" });
    try {
      const session = await signInWithApple(identityToken, guestToken, opts.appleVerifier);
      return { ...session, balance: await getBalance(session.userId) };
    } catch {
      return reply.code(401).send({ error: "apple_verification_failed" });
    }
  });

  // --- Konto / Wallet (auth-pflichtig) ---
  app.get("/me", { preHandler: requireAuth }, async (req) => {
    const { rows } = await pool.query(
      "select id, kind, display_name from users where id = $1",
      [req.userId],
    );
    const u = rows[0];
    return { userId: u.id, kind: u.kind, displayName: u.display_name, balance: await getBalance(req.userId!) };
  });

  app.get("/wallet", { preHandler: requireAuth }, async (req) => {
    return { balance: await getBalance(req.userId!) };
  });

  app.get("/wallet/history", { preHandler: requireAuth }, async (req) => {
    return { entries: await history(req.userId!) };
  });

  // --- Spiele & Quoten (öffentlich lesbar) ---
  app.get("/matches", async () => {
    return { matches: await listMatches() };
  });

  app.get("/outrights", async () => {
    return { outrights: await listOutrights() };
  });

  // --- ARENA Liga (B5): aktuelle Runde; Wetten laufen über POST /bets ---
  app.get("/league/current", async () => {
    const round = (await currentRound()) ?? (await ensureLeagueRound());
    return { round };
  });

  // --- Engagement (B7-Kern): XP/Level, 3h-Bonus + Rad, Freispiele ---
  app.get("/engagement", { preHandler: requireAuth }, async (req) => {
    return { engagement: await getEngagement(req.userId!) };
  });

  app.post("/bonus/claim", { preHandler: requireAuth }, async (req) => {
    return claimBonus(req.userId!);
  });

  app.post("/spins/play", { preHandler: requireAuth }, async (req) => {
    return playSpin(req.userId!);
  });

  app.post<{ Params: { part: string } }>(
    "/stadium/:part/upgrade",
    { preHandler: requireAuth },
    async (req) => upgradeStadium(req.userId!, req.params.part),
  );

  app.post<{ Body: { pick?: string } }>("/tipp", { preHandler: requireAuth }, async (req, reply) => {
    const pick = req.body?.pick;
    if (pick !== "1" && pick !== "X" && pick !== "2") {
      return reply.code(400).send({ error: "pick (1|X|2) erforderlich" });
    }
    return placeDailyPick(req.userId!, pick);
  });

  // --- Wetten (auth-pflichtig) ---
  app.post<{ Body: { stake?: number; legs?: LegInput[]; idempotencyKey?: string } }>(
    "/bets",
    { preHandler: requireAuth },
    async (req, reply) => {
      const { stake, legs, idempotencyKey } = req.body ?? {};
      if (typeof stake !== "number" || !Array.isArray(legs) || !idempotencyKey) {
        return reply.code(400).send({ error: "stake, legs und idempotencyKey erforderlich" });
      }
      const bet = await placeBet(req.userId!, stake, legs, idempotencyKey);
      return { bet, balance: await getBalance(req.userId!) };
    },
  );

  app.get("/bets", { preHandler: requireAuth }, async (req) => {
    return { bets: await listBets(req.userId!) };
  });

  app.get<{ Params: { id: string } }>("/bets/:id", { preHandler: requireAuth }, async (req, reply) => {
    const bet = await getBet(req.params.id);
    if (!bet) return reply.code(404).send({ error: "not_found" });
    // Fremde Wetten nicht preisgeben.
    const { rows } = await pool.query("select user_id from bets where id = $1", [req.params.id]);
    if (rows[0]?.user_id !== req.userId) return reply.code(404).send({ error: "not_found" });
    return { bet };
  });

  // --- Admin: Ergebnis-Eingang & Odds-Sync (B4-Übergang; später Feed-getrieben) ---
  async function requireAdmin(req: FastifyRequest, reply: FastifyReply): Promise<void> {
    const given = String(req.headers["x-admin-key"] ?? "");
    const expected = config.adminKey;
    const ok =
      expected.length > 0 &&
      given.length === expected.length &&
      timingSafeEqual(Buffer.from(given), Buffer.from(expected));
    if (!ok) await reply.code(expected ? 403 : 503).send({ error: expected ? "forbidden" : "admin_disabled" });
  }

  app.post<{ Params: { id: string }; Body: { home?: number; away?: number } }>(
    "/admin/matches/:id/result",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { home, away } = req.body ?? {};
      if (typeof home !== "number" || typeof away !== "number") {
        return reply.code(400).send({ error: "home und away erforderlich" });
      }
      return recordResult(req.params.id, home, away);
    },
  );

  app.post<{ Params: { id: string } }>(
    "/admin/matches/:id/void",
    { preHandler: requireAdmin },
    async (req) => voidMatch(req.params.id),
  );

  app.post("/admin/sync-odds", { preHandler: requireAdmin }, async () => fetchAndIngest());

  // --- Dev-Faucet (nur außerhalb Produktion) ---
  if (config.enableDevEndpoints) {
    app.post("/wallet/demo-grant", { preHandler: requireAuth }, async (req) => {
      const result = await post(req.userId!, {
        amount: 100_000,
        reason: "admin_demo",
        idempotencyKey: `demo:${req.userId}:${randomUUID()}`,
      });
      return { balance: result.balance };
    });
  }

  // --- Fehler-Mapping ---
  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof InsufficientFundsError) {
      return reply.code(409).send({ error: "insufficient_funds", needed: err.needed, available: err.available });
    }
    if (err instanceof PlacementError) {
      return reply.code(422).send({ error: err.code, message: err.message });
    }
    if (err instanceof ResultConflictError) {
      return reply.code(409).send({ error: "result_conflict", message: err.message });
    }
    if (err instanceof ClaimNotReadyError) {
      return reply.code(409).send({ error: "bonus_not_ready", readyAt: err.readyAt.toISOString() });
    }
    if (err instanceof NoSpinsError) {
      return reply.code(409).send({ error: "no_free_spins" });
    }
    if (err instanceof StadiumError) {
      return reply.code(422).send({ error: err.code, message: err.message });
    }
    if (err instanceof TippError) {
      return reply.code(err.code === "already_picked" ? 409 : 422).send({ error: err.code, message: err.message });
    }
    if (err instanceof MatchNotFoundError) {
      return reply.code(404).send({ error: "match_not_found", message: err.message });
    }
    reply.code(500).send({ error: "internal_error" });
  });

  return app;
}
