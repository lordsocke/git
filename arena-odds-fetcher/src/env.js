// Minimal .env loader (zero dependencies). Loads KEY=VALUE lines from a .env
// file in the project root into process.env WITHOUT overwriting variables that
// are already set in the real environment (real env wins).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const PROJECT_ROOT = path.resolve(__dirname, '..');

export function loadDotEnv(file = path.join(PROJECT_ROOT, '.env')) {
  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch {
    return; // no .env present — fine, rely on real env + defaults
  }
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    // Strip matching surrounding quotes.
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

function str(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v;
}

function int(name, fallback) {
  const v = parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(v) ? v : fallback;
}

// Hard politeness floor: never poll the source faster than once per 60s,
// regardless of what REFRESH_SECONDS is set to.
export const MIN_REFRESH_SECONDS = 60;

export function buildConfig() {
  loadDotEnv();

  const requested = int('REFRESH_SECONDS', 120);
  const refreshSeconds = Math.max(MIN_REFRESH_SECONDS, requested);

  return {
    port: int('PORT', 8080),
    host: str('HOST', '127.0.0.1'),
    refreshSeconds,
    refreshSecondsRequested: requested,
    refreshClamped: refreshSeconds !== requested,
    refreshToken: str('REFRESH_TOKEN', ''),
    userAgent: str('SOURCE_USER_AGENT', 'arena-poc-odds/1.0'),
    oddsBaseUrl: str('ODDS_BASE_URL', 'https://oddsservice-msw-mb-de.cashpoint.solutions'),
    cp: {
      systemId: str('CP_SYSTEM_ID', '1'),
      language: str('CP_LANGUAGE', '1'),
      location: str('CP_LOCATION', '82'),
      clientCountry: str('CP_CLIENT_COUNTRY', '82'),
      // 10 = offizielles Deutschland-Angebot (Doku v0.5); 1 = volles Angebot (AT).
      jurisdictionId: int('CP_JURISDICTION_ID', 10),
    },
    snapshotPath: path.resolve(PROJECT_ROOT, str('SNAPSHOT_PATH', './snapshots/odds-latest.json')),
    logLevel: str('LOG_LEVEL', 'info'),
    requestTimeoutMs: int('REQUEST_TIMEOUT_MS', 25000),
  };
}
