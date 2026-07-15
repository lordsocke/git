// Thin client for the Cashpoint odds service — seit 15.07.2026 ausgerichtet an
// der OFFIZIELLEN External-Integration-Doku ("Oddsservice v0.5", via Merkur/
// Cashpoint): POST /odds/getGames/11, Header X-Language/X-System-Id,
// jurisdiction 10 (DE-Angebot), containerIds (283 = FIFA World Cup 2026) und
// marketIds-Filter. Wichtig: Die Doku verschweigt x-location/x-client-country —
// ohne sie kommen Team-/Marktnamen als numerische Übersetzungs-IDs zurück
// (empirisch verifiziert), daher senden wir weiterhin alle vier Header.
// Read-only, kein Auth, keine Cookies. Historie der Entdeckung: DISCOVERY.md.
import { log } from './logger.js';

export class CashpointClient {
  constructor(config) {
    this.baseUrl = config.oddsBaseUrl.replace(/\/+$/, '');
    this.cp = config.cp;
    this.userAgent = config.userAgent;
    this.timeoutMs = config.requestTimeoutMs;
  }

  headers() {
    // Context headers observed on the site's own requests. `x-language: 1`
    // makes the server resolve team/league names to German strings instead of
    // returning numeric translation IDs.
    return {
      'content-type': 'application/json',
      accept: 'application/json, text/plain, */*',
      'user-agent': this.userAgent,
      'accept-language': 'de-DE',
      'x-system-id': String(this.cp.systemId),
      'x-language': String(this.cp.language),
      'x-location': String(this.cp.location),
      'x-client-country': String(this.cp.clientCountry),
    };
  }

  async post(pathname, body, { retries = 2 } = {}) {
    const url = `${this.baseUrl}${pathname}`;
    let lastErr;
    for (let attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        const backoff = 500 * 2 ** (attempt - 1); // 500ms, 1000ms, ...
        await sleep(backoff);
        log.debug(`retry ${attempt} for ${pathname} after ${backoff}ms`);
      }
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.timeoutMs);
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: this.headers(),
          body: JSON.stringify(body),
          signal: controller.signal,
          redirect: 'manual',
        });
        clearTimeout(timer);
        if (res.status >= 300 && res.status < 400) {
          // A redirect here almost certainly means geo-blocking (302 -> /restrict).
          throw new Error(`unexpected redirect ${res.status} (geo-block?) for ${pathname}`);
        }
        if (!res.ok) {
          const text = await res.text().catch(() => '');
          throw new Error(`HTTP ${res.status} for ${pathname}: ${text.slice(0, 200)}`);
        }
        return await res.json();
      } catch (err) {
        clearTimeout(timer);
        lastErr = err;
        log.warn(`request failed (${pathname}, attempt ${attempt + 1}/${retries + 1})`, err.message);
      }
    }
    throw lastErr;
  }

  // Full filter tree (contains the league catalogue used for name->ID mapping).
  getFilters(gameTypes, jurisdictionId) {
    return this.post('/odds/getFilters/11', {
      gameTypes,
      enableGameCounts: true,
      jurisdictionId,
      limit: 1,
    });
  }

  // Games für Ligen ODER einen Container (WM etc.), optional markt-gefiltert.
  // `selector` = { leagueIds: [...] } oder { containerIds: [...] }.
  // Die Doku nutzt in den Beispielen mal `jurisdiction`, mal `jurisdictionId` —
  // wir senden beide Schreibweisen (empirisch: beide Varianten akzeptiert).
  getGames(selector, gameTypes, jurisdictionId, limit = 20, marketIds = undefined) {
    return this.post('/odds/getGames/11', {
      gameTypes,
      ...selector,
      jurisdiction: jurisdictionId,
      jurisdictionId,
      limit,
      ...(marketIds && marketIds.length ? { marketIds } : {}),
    });
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
