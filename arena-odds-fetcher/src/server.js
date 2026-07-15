// HTTP entrypoint. Zero-dependency server built on node:http.
//
// Routes:
//   GET  /health              -> { ok, lastFetchAt, stale, source, ... }
//   GET  /odds                -> full target-schema document (from cache)
//   GET  /odds/:competitionId -> single competition
//   POST /refresh             -> manual refresh (token-protected)
import http from 'node:http';
import { buildConfig, MIN_REFRESH_SECONDS } from './env.js';
import { setLogLevel, log } from './logger.js';
import { CashpointClient } from './cashpointClient.js';
import { OddsStore } from './store.js';
import { Refresher } from './refresher.js';
import { validateDocument } from './validate.js';
import { SOURCE_LABEL } from './config.js';

const config = buildConfig();
setLogLevel(config.logLevel);

const client = new CashpointClient(config);
const store = new OddsStore(config);
store.seedFromSnapshot();
const refresher = new Refresher(client, store, config);

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj, null, 2);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store',
  });
  res.end(body);
}

function tokenOk(req, url) {
  if (!config.refreshToken) return false; // refresh disabled when no token set
  const auth = req.headers['authorization'] || '';
  const bearer = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  const qToken = url.searchParams.get('token') || '';
  return bearer === config.refreshToken || qToken === config.refreshToken;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname.replace(/\/+$/, '') || '/';
  log.debug(`${req.method} ${pathname}`);

  try {
    // --- GET /health ---
    if (req.method === 'GET' && pathname === '/health') {
      const doc = store.current();
      return sendJson(res, 200, {
        ok: store.hasData(),
        source: SOURCE_LABEL,
        lastFetchAt: store.lastFetchAt ? store.lastFetchAt.toISOString() : null,
        lastAttemptAt: store.lastAttemptAt ? store.lastAttemptAt.toISOString() : null,
        stale: doc ? doc.stale : true,
        staleSinceMinutes: store.isStale() ? store.staleSinceMinutes() : 0,
        refreshing: store.refreshing,
        lastError: store.lastError,
        refreshSeconds: config.refreshSeconds,
        refreshClamped: config.refreshClamped,
      });
    }

    // --- GET /odds ---
    if (req.method === 'GET' && pathname === '/odds') {
      const doc = store.current();
      if (!doc) {
        return sendJson(res, 503, {
          error: 'no_data_yet',
          message: 'No successful fetch has completed yet.',
          stale: true,
        });
      }
      return sendJson(res, 200, doc);
    }

    // --- GET /odds/:competitionId ---
    const oddsMatch = pathname.match(/^\/odds\/([a-z0-9_-]+)$/i);
    if (req.method === 'GET' && oddsMatch) {
      const doc = store.current();
      if (!doc) {
        return sendJson(res, 503, { error: 'no_data_yet', stale: true });
      }
      const comp = doc.competitions.find((c) => c.id === oddsMatch[1].toLowerCase());
      if (!comp) {
        return sendJson(res, 404, {
          error: 'unknown_competition',
          competitionId: oddsMatch[1],
          available: doc.competitions.map((c) => c.id),
        });
      }
      return sendJson(res, 200, {
        source: doc.source,
        fetchedAt: doc.fetchedAt,
        stale: doc.stale,
        ...(doc.staleSinceMinutes != null ? { staleSinceMinutes: doc.staleSinceMinutes } : {}),
        competition: comp,
      });
    }

    // --- POST /refresh ---
    if (req.method === 'POST' && pathname === '/refresh') {
      if (!tokenOk(req, url)) {
        return sendJson(res, 401, {
          error: 'unauthorized',
          message: config.refreshToken
            ? 'Provide the refresh token via "Authorization: Bearer <token>" or ?token=.'
            : 'Manual refresh is disabled: no REFRESH_TOKEN configured.',
        });
      }
      const result = await refresher.refresh({ force: false, reason: 'manual' });
      if (result && result.skipped) {
        return sendJson(res, 429, {
          error: 'rate_limited',
          message: `Hard minimum ${MIN_REFRESH_SECONDS}s between upstream refreshes.`,
          retryAfterSeconds: result.retryAfterSeconds,
        });
      }
      const doc = store.current();
      return sendJson(res, result && result.ok ? 200 : 502, {
        ok: !!(result && result.ok),
        error: result && result.error ? result.error : undefined,
        fetchedAt: store.lastFetchAt ? store.lastFetchAt.toISOString() : null,
        stale: doc ? doc.stale : true,
        matches: doc ? doc.competitions.reduce((n, c) => n + c.matches.length, 0) : 0,
      });
    }

    // --- GET / (info) ---
    if (req.method === 'GET' && pathname === '/') {
      return sendJson(res, 200, {
        service: 'arena-odds-fetcher',
        source: SOURCE_LABEL,
        endpoints: ['GET /health', 'GET /odds', 'GET /odds/:competitionId', 'POST /refresh'],
      });
    }

    return sendJson(res, 404, { error: 'not_found', path: pathname });
  } catch (err) {
    log.error('unhandled request error', err.stack || err.message);
    return sendJson(res, 500, { error: 'internal_error', message: err.message });
  }
});

server.listen(config.port, config.host, () => {
  log.info(`arena-odds-fetcher listening on http://${config.host}:${config.port}`);
  log.info(
    `refresh every ${config.refreshSeconds}s` +
      (config.refreshClamped ? ` (requested ${config.refreshSecondsRequested}s, clamped to floor)` : ''),
  );
  if (!config.refreshToken) log.warn('REFRESH_TOKEN not set — POST /refresh is disabled');
  refresher.start();
});

// Optional readiness self-check aid: validate on each successful fetch in debug.
export { server, store, refresher, validateDocument };

function shutdown(sig) {
  log.info(`received ${sig}, shutting down`);
  refresher.stop();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
