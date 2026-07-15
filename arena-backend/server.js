/* =====================================================================
   ARENA Demo-Backend v0 — server-autoritative ARENA Liga (RGS-Muster)

   Der Server ist die einzige Wahrheit: Er simuliert die Liga, berechnet
   die Quoten EXAKT aus demselben Modell (Kalibrier-Invariante, Konzept
   Kap. 6.6), nimmt Wetten zu SERVER-Quoten an und settlet automatisch.
   Demo-Grenzen: In-Memory-State (Neustart = Reset), keine Auth, eine
   Instanz — im Produkt: Postgres-Ledger, Idempotenz, Auth, Skalierung.
===================================================================== */
"use strict";
const express = require("express");
const crypto = require("crypto");

const app = express();
app.use(express.json());
app.use((req, res, next) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("X-Arena-Demo", "v0");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

/* ---------- Liga-Engine (identisches Modell wie die Prototypen) ---------- */
const TEAMS = [
  { n: "Aurora FC", s: 82 }, { n: "Union Kobalt", s: 78 },
  { n: "SC Meridian", s: 75 }, { n: "Athletico Nova", s: 73 },
  { n: "FC Boreas", s: 70 }, { n: "Sparta Lyra", s: 67 },
  { n: "Dynamo Quarz", s: 64 }, { n: "Real Zephyr", s: 60 },
];
const PAYOUT = 0.925;                 // Hold 7,5 % des Einsatzes
const GOAL_MINUTES = 89;              // Tore möglich in Minute 1–89
const GOAL_P = 2.685 / GOAL_MINUTES;  // λ ≈ 2,685 — identisch mit der Preisbildung
const PAUSE_S = 30, FT_S = 8;         // Produkt-Taktung: 1 s = 1 Spielminute ⇒ Zyklus ~128 s
const MIN_STAKE = 5_000, MAX_STAKE = 1_000_000;
const CLOSE_MIN = 80;                 // Annahmeschluss

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const r2 = v => Math.round(clamp(v, 1.03, 29) * 100) / 100;

function poisArr(lam, n) {
  const a = [Math.exp(-lam)];
  for (let k = 1; k <= n; k++) a.push(a[k - 1] * lam / k);
  return a;
}
/* Exakte Preisableitung aus dem Simulationsmodell (EV je Markt = −7,5 %) */
function odds(q, gh, ga, t) {
  const lam = GOAL_P * GOAL_MINUTES * (1 - t), N = 12;
  const ph = poisArr(lam * q, N), pa = poisArr(lam * (1 - q), N);
  let p1 = 0, px = 0, p2 = 0, pOver = 0;
  for (let i = 0; i <= N; i++) for (let j = 0; j <= N; j++) {
    const p = ph[i] * pa[j], H = gh + i, A = ga + j;
    if (H > A) p1 += p; else if (H < A) p2 += p; else px += p;
    if (H + A > 2.5) pOver += p;
  }
  const o = {
    "1X2|1": r2(PAYOUT / Math.max(p1, 0.033)),
    "1X2|X": r2(PAYOUT / Math.max(px, 0.033)),
    "1X2|2": r2(PAYOUT / Math.max(p2, 0.033)),
  };
  if (pOver > 0.005 && pOver < 0.995) {
    o["OU|Über 2,5"] = r2(PAYOUT / pOver);
    o["OU|Unter 2,5"] = r2(PAYOUT / (1 - pOver));
  }
  return o;
}

let matchSeq = 0;
let match = null;
const table = TEAMS.map(() => ({ p: 0, sp: 0 }));

function newMatch() {
  matchSeq++;
  let h = Math.floor(Math.random() * TEAMS.length);
  let a = Math.floor(Math.random() * TEAMS.length);
  if (a === h) a = (a + 1 + Math.floor(Math.random() * (TEAMS.length - 1))) % TEAMS.length;
  const q = clamp(0.53 + (TEAMS[h].s - TEAMS[a].s) * 0.01, 0.15, 0.85);
  match = {
    id: matchSeq, phase: "pause", h, a, q, min: 0, gh: 0, ga: 0,
    until: Date.now() + PAUSE_S * 1000, suspUntil: 0,
    odds: odds(q, 0, 0, 0), events: [],
  };
}
newMatch();

function settleMatch() {
  const out = match.gh > match.ga ? "1" : match.gh < match.ga ? "2" : "X";
  const total = match.gh + match.ga;
  if (out === "1") { table[match.h].p += 3; } else if (out === "2") { table[match.a].p += 3; }
  else { table[match.h].p += 1; table[match.a].p += 1; }
  table[match.h].sp++; table[match.a].sp++;
  for (const bet of bets.values()) {
    if (bet.status !== "open" || bet.matchId !== match.id) continue;
    const won = bet.market === "1X2" ? bet.pick === out
      : bet.pick.startsWith("Über") ? total > 2.5 : total < 2.5;
    bet.status = won ? "won" : "lost";
    bet.settledAt = Date.now();
    if (won) {
      bet.payout = Math.round(bet.stake * bet.odds);
      wallets.get(bet.playerId).coins += bet.payout;
    }
  }
}

setInterval(() => {
  const now = Date.now();
  if (match.phase === "pause") {
    if (now >= match.until) { match.phase = "live"; match.min = 0; }
  } else if (match.phase === "live") {
    if (now < match.suspUntil) return;
    match.min = Math.min(90, match.min + 1);   // 1 s = 1 Spielminute
    if (match.min <= GOAL_MINUTES && Math.random() < GOAL_P) {
      const home = Math.random() < match.q;    // Torschütze = Preismodell-Anteil q
      if (home) match.gh++; else match.ga++;
      match.events.push(`${match.min}′ ⚽ ${TEAMS[home ? match.h : match.a].n}`);
      match.suspUntil = now + 2500;            // Markt-Suspendierung
      match.odds = odds(match.q, match.gh, match.ga, match.min / 90);
    }
    if (match.min % 3 === 0) match.odds = odds(match.q, match.gh, match.ga, match.min / 90);
    if (match.min >= 90) {
      match.phase = "ft";
      match.until = now + FT_S * 1000;
      settleMatch();
    }
  } else if (now >= match.until) {
    newMatch();
  }
}, 1000);

/* ---------- Wallet & Wetten (In-Memory, Demo) ---------- */
const wallets = new Map();   // playerId → {name, coins, createdAt}
const bets = new Map();      // betId → bet

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "arena-demo-backend", version: "0.1.0", uptimeS: Math.round(process.uptime()), players: wallets.size, matchId: match.id });
});

app.post("/api/register", (req, res) => {
  const playerId = crypto.randomUUID();
  const name = String(req.body?.name || "Gast").slice(0, 24);
  wallets.set(playerId, { name, coins: 1_000_000, createdAt: Date.now() });
  res.json({ playerId, name, coins: 1_000_000 });
});

/* Ein Poll-Endpoint für alles: Spielzustand, Quoten, Tabelle, Wallet, Wetten */
app.get("/api/state", (req, res) => {
  const playerId = req.query.playerId;
  const wallet = playerId ? wallets.get(playerId) : null;
  const myBets = playerId
    ? [...bets.values()].filter(b => b.playerId === playerId).slice(-20).reverse()
    : [];
  res.json({
    serverTime: Date.now(),
    match: {
      id: match.id, phase: match.phase,
      home: TEAMS[match.h].n, away: TEAMS[match.a].n,
      min: match.min, gh: match.gh, ga: match.ga,
      suspended: Date.now() < match.suspUntil,
      bettingOpen: match.phase !== "ft" && Date.now() >= match.suspUntil && match.min < CLOSE_MIN,
      countdownS: match.phase !== "live" ? Math.max(0, Math.ceil((match.until - Date.now()) / 1000)) : null,
      odds: match.odds, events: match.events,
      payout: PAYOUT,
    },
    table: TEAMS.map((t, i) => ({ team: t.n, punkte: table[i].p, spiele: table[i].sp }))
      .sort((x, y) => y.punkte - x.punkte),
    wallet: wallet ? { name: wallet.name, coins: wallet.coins } : null,
    bets: myBets,
  });
});

/* Wett-Annahme: Server-Quoten sind bindend (Repricing by design), Annahmeschluss 80′ */
app.post("/api/bets", (req, res) => {
  const { playerId, market, pick, stake } = req.body || {};
  const wallet = wallets.get(playerId);
  if (!wallet) return res.status(404).json({ error: "Unbekannter Spieler — erst /api/register aufrufen." });
  const st = Math.floor(Number(stake) || 0);
  if (st < MIN_STAKE || st > MAX_STAKE) return res.status(400).json({ error: `Einsatz ${MIN_STAKE}–${MAX_STAKE}.` });
  if (wallet.coins < st) return res.status(400).json({ error: "Nicht genug Coins." });
  if (match.phase === "ft") return res.status(409).json({ error: "Spiel beendet — nächster Anstoß gleich." });
  if (Date.now() < match.suspUntil) return res.status(409).json({ error: "Tor! Märkte kurz gesperrt." });
  if (match.phase === "live" && match.min >= CLOSE_MIN) return res.status(409).json({ error: `Wettannahme geschlossen (ab ${CLOSE_MIN}′).` });
  const key = `${market}|${pick}`;
  const currentOdds = match.odds[key];
  if (!currentOdds) return res.status(400).json({ error: `Markt ${key} nicht verfügbar.` });

  wallet.coins -= st;
  const bet = {
    id: crypto.randomUUID(), playerId, matchId: match.id,
    matchLabel: `${TEAMS[match.h].n} – ${TEAMS[match.a].n}`,
    market, pick, odds: currentOdds, stake: st,
    status: "open", payout: 0, placedAt: Date.now(),
  };
  bets.set(bet.id, bet);
  res.json({ bet, wallet: { coins: wallet.coins } });
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`ARENA Demo-Backend v0 auf Port ${port}`));
