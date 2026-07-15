// Holds the last successfully-fetched document, tracks staleness, and persists
// a snapshot to disk after every successful refresh.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { log } from './logger.js';

export class OddsStore {
  constructor(config) {
    this.config = config;
    this.lastGood = null; // the last successful document (fresh copy)
    this.lastFetchAt = null; // Date of last successful fetch
    this.lastAttemptAt = null; // Date of last attempt (success or fail)
    this.lastError = null; // string message of last failure
    this.refreshing = false;
  }

  hasData() {
    return this.lastGood !== null;
  }

  // Returns the document to serve, with stale flags applied when appropriate.
  current() {
    if (!this.lastGood) return null;
    const stale = this.isStale();
    const doc = structuredClone(this.lastGood);
    doc.stale = stale;
    if (stale) {
      doc.staleSinceMinutes = this.staleSinceMinutes();
      doc.staleSince = this.lastFetchAt ? this.lastFetchAt.toISOString() : null;
    }
    return doc;
  }

  // "Stale" = the last successful fetch is older than one full refresh cycle
  // plus a grace margin (so a single slow refresh doesn't flip the flag).
  isStale() {
    if (!this.lastFetchAt) return true;
    const ageMs = Date.now() - this.lastFetchAt.getTime();
    const thresholdMs = (this.config.refreshSeconds * 2 + 15) * 1000;
    return ageMs > thresholdMs;
  }

  staleSinceMinutes() {
    if (!this.lastFetchAt) return null;
    return Math.floor((Date.now() - this.lastFetchAt.getTime()) / 60000);
  }

  recordSuccess(doc) {
    this.lastGood = doc;
    this.lastFetchAt = new Date();
    this.lastAttemptAt = this.lastFetchAt;
    this.lastError = null;
  }

  recordFailure(err) {
    this.lastAttemptAt = new Date();
    this.lastError = err?.message || String(err);
  }

  async writeSnapshot(doc) {
    const file = this.config.snapshotPath;
    try {
      await fsp.mkdir(path.dirname(file), { recursive: true });
      const tmp = `${file}.tmp`;
      await fsp.writeFile(tmp, JSON.stringify(doc, null, 2), 'utf8');
      await fsp.rename(tmp, file); // atomic replace
      log.debug(`snapshot written -> ${file}`);
    } catch (err) {
      log.error('failed to write snapshot', err.message);
    }
  }

  // Attempt to seed from an existing snapshot on startup so the service can
  // serve (stale) data immediately even before the first live fetch.
  seedFromSnapshot() {
    try {
      const raw = fs.readFileSync(this.config.snapshotPath, 'utf8');
      const doc = JSON.parse(raw);
      if (doc && Array.isArray(doc.competitions)) {
        this.lastGood = doc;
        // Treat the on-disk fetchedAt as the last good time if parseable.
        const t = Date.parse(doc.fetchedAt);
        this.lastFetchAt = Number.isFinite(t) ? new Date(t) : null;
        log.info(`seeded from snapshot (${this.config.snapshotPath})`);
        return true;
      }
    } catch {
      /* no snapshot yet — normal on first run */
    }
    return false;
  }
}
