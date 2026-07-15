// Azure Functions v4 (Node, ESM) — dünne Serverless-Schicht über der bestehenden
// Fetch-/Normalisierungs-Logik (src/*). Läuft in Germany West Central (Frankfurt),
// damit der Merkur-/Cashpoint-Geo-Block (nur DE erreichbar) nicht greift.
//
// Strategie: Lazy-Cache statt Storage-Account/Blob. Der erste (Cold-Start-)Aufruf
// liefert sofort den mitgelieferten echten Snapshot; ist er älter als die TTL,
// wird im Hintergrund neu von Merkur geladen (blockiert die Antwort nicht). Ein
// Timer aktualisiert zusätzlich alle 2 Minuten.
import { app } from "@azure/functions";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildConfig } from "../src/env.js";
import { CashpointClient } from "../src/cashpointClient.js";
import { fetchOddsDocument } from "../src/fetcher.js";
import { SOURCE_LABEL } from "../src/config.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const config = buildConfig();
const client = new CashpointClient(config);

const TTL_MS = 120_000;                 // ab hier gilt der Cache als "auffrischbar"
const STALE_MS = TTL_MS * 2 + 15_000;   // ab hier wird stale:true ausgewiesen

let cache = null;
let cacheTime = 0;
let refreshing = false;
let lastError = null;

// Cache mit dem mitgelieferten echten Snapshot vorbelegen (Cold-Start liefert Daten)
try {
  const seed = JSON.parse(
    fs.readFileSync(path.resolve(__dirname, "../snapshots/odds-latest.json"), "utf8"),
  );
  if (seed && Array.isArray(seed.competitions)) {
    cache = seed;
    cacheTime = Date.parse(seed.fetchedAt) || 0;
  }
} catch {
  /* kein Seed vorhanden — erster HTTP-Aufruf lädt live */
}

async function refresh(ctx) {
  if (refreshing) return;
  refreshing = true;
  try {
    const doc = await fetchOddsDocument(client, config);
    cache = doc;
    cacheTime = Date.now();
    lastError = null;
    const n = doc.competitions.reduce((s, c) => s + c.matches.length, 0);
    ctx?.log(`odds refreshed: ${n} matches across ${doc.competitions.length} competitions`);
  } catch (e) {
    lastError = e?.message || String(e);
    ctx?.log(`odds refresh failed: ${lastError}`);
  } finally {
    refreshing = false;
  }
}

const ageMs = () => Date.now() - cacheTime;
const isStale = () => ageMs() > STALE_MS;

function docForResponse() {
  if (!cache) return null;
  const d = structuredClone(cache);
  d.stale = isStale();
  if (d.stale) d.staleSinceMinutes = Math.floor(ageMs() / 60000);
  return d;
}

// Hintergrund-Refresh anstoßen, ohne die Antwort zu blockieren (fire-and-forget).
function maybeRefresh(ctx) {
  if (!cache || (ageMs() > TTL_MS && !refreshing)) {
    // Bei komplett leerem Cache warten wir NICHT — wir liefern 503 und laden nach.
    refresh(ctx);
  }
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

app.http("odds", {
  route: "odds",
  methods: ["GET"],
  authLevel: "anonymous",
  handler: async (_req, ctx) => {
    maybeRefresh(ctx);
    const d = docForResponse();
    if (!d) return { status: 503, headers: CORS, body: JSON.stringify({ error: "no_data_yet", stale: true }) };
    return { status: 200, headers: CORS, body: JSON.stringify(d) };
  },
});

app.http("odds-comp", {
  route: "odds/{comp}",
  methods: ["GET"],
  authLevel: "anonymous",
  handler: async (req, ctx) => {
    maybeRefresh(ctx);
    const d = docForResponse();
    if (!d) return { status: 503, headers: CORS, body: JSON.stringify({ error: "no_data_yet" }) };
    const id = String(req.params.comp || "").toLowerCase();
    const c = d.competitions.find((x) => x.id === id);
    if (!c) {
      return {
        status: 404, headers: CORS,
        body: JSON.stringify({ error: "unknown_competition", available: d.competitions.map((x) => x.id) }),
      };
    }
    return {
      status: 200, headers: CORS,
      body: JSON.stringify({ source: d.source, fetchedAt: d.fetchedAt, stale: d.stale, competition: c }),
    };
  },
});

app.http("health", {
  route: "health",
  methods: ["GET"],
  authLevel: "anonymous",
  handler: async () => ({
    status: 200, headers: CORS,
    body: JSON.stringify({
      ok: !!cache,
      source: SOURCE_LABEL,
      lastFetchAt: cacheTime ? new Date(cacheTime).toISOString() : null,
      stale: isStale(),
      refreshing,
      lastError,
      region: "germanywestcentral",
    }),
  }),
});

// Proaktiver Refresh alle 2 Minuten (zusätzlich zum Lazy-Refresh bei HTTP-Zugriff)
app.timer("refresh-timer", {
  schedule: "0 */2 * * * *",
  handler: async (_t, ctx) => { await refresh(ctx); },
});
