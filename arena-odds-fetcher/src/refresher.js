// Owns refresh timing: the background interval, the hard 60s minimum gap
// between upstream full-refreshes, and de-duplication of concurrent refreshes.
import { fetchOddsDocument } from './fetcher.js';
import { MIN_REFRESH_SECONDS } from './env.js';
import { log } from './logger.js';

export class Refresher {
  constructor(client, store, config) {
    this.client = client;
    this.store = store;
    this.config = config;
    this.lastRunStartedAt = 0; // epoch ms of last upstream refresh start
    this.inFlight = null; // Promise of the currently running refresh, if any
    this.timer = null;
  }

  get minGapMs() {
    return MIN_REFRESH_SECONDS * 1000;
  }

  msUntilAllowed() {
    const elapsed = Date.now() - this.lastRunStartedAt;
    return Math.max(0, this.minGapMs - elapsed);
  }

  // Run a refresh. If one is already running, await it. If the hard rate limit
  // has not elapsed, either wait it out (force=true) or skip (force=false).
  async refresh({ force = false, reason = 'scheduled' } = {}) {
    if (this.inFlight) {
      log.debug(`refresh (${reason}) coalesced into in-flight run`);
      return this.inFlight;
    }
    const wait = this.msUntilAllowed();
    if (wait > 0) {
      if (!force) {
        log.debug(`refresh (${reason}) skipped — rate limit, ${Math.ceil(wait / 1000)}s remaining`);
        return { skipped: true, retryAfterSeconds: Math.ceil(wait / 1000) };
      }
      log.info(`refresh (${reason}) waiting ${Math.ceil(wait / 1000)}s for rate limit`);
      await sleep(wait);
    }

    this.lastRunStartedAt = Date.now();
    this.store.refreshing = true;
    this.inFlight = this._run(reason).finally(() => {
      this.inFlight = null;
      this.store.refreshing = false;
    });
    return this.inFlight;
  }

  async _run(reason) {
    const t0 = Date.now();
    try {
      const doc = await fetchOddsDocument(this.client, this.config);
      this.store.recordSuccess(doc);
      await this.store.writeSnapshot(doc);
      const matchCount = doc.competitions.reduce((n, c) => n + c.matches.length, 0);
      log.info(
        `refresh ok (${reason}) in ${Date.now() - t0}ms — ${doc.competitions.length} competitions, ${matchCount} matches`,
      );
      return { ok: true, document: doc };
    } catch (err) {
      this.store.recordFailure(err);
      log.error(`refresh failed (${reason}) — serving last good as stale`, err.message);
      return { ok: false, error: err.message };
    }
  }

  start() {
    // Kick off an immediate refresh, then schedule the interval.
    this.refresh({ force: true, reason: 'startup' });
    this.timer = setInterval(
      () => this.refresh({ force: false, reason: 'interval' }),
      this.config.refreshSeconds * 1000,
    );
    if (this.timer.unref) this.timer.unref();
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
