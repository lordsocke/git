# arena-odds-fetcher

Standalone odds building-block for the **ARENA** free-to-play sports betting POC.

It reads **public, read-only pre-match odds** from `merkurbets.de` (which is
served by the Cashpoint platform), normalizes them into the fixed ARENA
integration schema, and exposes them over a small HTTP service. It must run on a
host **inside Germany**, because merkurbets.de geo-blocks non-DE clients
(`302 → /restrict/…`).

> This is a **POC bridge**. In the final product the feed comes in-house from the
> Cashpoint platform; this fetcher only exists to get real odds snapshots now.
> See [`DISCOVERY.md`](./DISCOVERY.md) for exactly how the upstream endpoints were
> found and how to call them without this service.

- **No login, no bet placement, no auth bypass.** Only the public JSON the site's
  own web app requests.
- **Polite by design:** cached reads, one full refresh every 120 s (configurable),
  a **hard 60 s floor** between upstream refreshes, clean User-Agent, retry/backoff.
- **Zero runtime dependencies** — plain Node.js ≥ 20 (`node:http` + global `fetch`).
  Playwright is an *optional* dependency used only by the discovery tool.

---

## Quick start

```bash
cd arena-odds-fetcher
cp .env.example .env          # then edit REFRESH_TOKEN at least
npm install                   # installs nothing required; optional Playwright may be skipped
npm start
```

The service performs a first refresh immediately on boot and writes
`snapshots/odds-latest.json`. Check it:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/odds
curl http://127.0.0.1:8080/odds/wm
```

One-off fetch to stdout + snapshot (no server), handy for manual transfer:

```bash
npm run fetch:once          # pretty JSON to stdout, writes snapshot
npm run fetch:validate      # fetch + schema-validate, exit non-zero on problems
```

Run the unit tests (offline, against captured fixtures):

```bash
npm test
```

---

## HTTP API

| Method + path            | Description                                                              |
| ------------------------ | ------------------------------------------------------------------------ |
| `GET /health`            | `{ ok, source, lastFetchAt, lastAttemptAt, stale, staleSinceMinutes, refreshing, lastError, refreshSeconds, refreshClamped }` |
| `GET /odds`              | The complete schema document (served from cache).                        |
| `GET /odds/:competitionId` | A single competition (`wm`, `bl`, `pl`, `ll`, `cl`, `dfb`). `404` if unknown. |
| `POST /refresh`          | Manual refresh. **Token-protected** (see below). `429` if inside the 60 s floor. |
| `GET /`                  | Service info / endpoint list.                                            |

### `POST /refresh` auth

Protected by `REFRESH_TOKEN` from `.env`. Send it either way:

```bash
curl -X POST -H "Authorization: Bearer $REFRESH_TOKEN" http://127.0.0.1:8080/refresh
curl -X POST "http://127.0.0.1:8080/refresh?token=$REFRESH_TOKEN"
```

If `REFRESH_TOKEN` is empty, manual refresh is **disabled** (`401`); the
background loop still runs.

### Staleness

If a refresh fails, the **last good document keeps being served** with
`stale: true` and `staleSinceMinutes` set, and the process does **not** crash.
`stale` flips to `true` once the last successful fetch is older than
`2 × REFRESH_SECONDS + 15 s`.

---

## Configuration (`.env`)

All optional; defaults in parentheses. See [`.env.example`](./.env.example).

| Variable             | Default                                              | Notes                                                       |
| -------------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| `PORT`               | `8080`                                               |                                                             |
| `HOST`               | `127.0.0.1`                                           | Use `0.0.0.0` to expose; `127.0.0.1` keeps it local.        |
| `REFRESH_SECONDS`    | `120`                                                | Background refresh interval. **Clamped up to 60 s minimum.** |
| `REFRESH_TOKEN`      | *(empty)*                                            | Protects `POST /refresh`. Empty ⇒ manual refresh disabled.  |
| `SOURCE_USER_AGENT`  | `arena-poc-odds/1.0`                                  |                                                             |
| `ODDS_BASE_URL`      | `https://oddsservice-msw-mb-de.cashpoint.solutions`  | Upstream odds service.                                      |
| `CP_LANGUAGE`        | `1`                                                  | `x-language` header (German name resolution).               |
| `CP_SYSTEM_ID` / `CP_LOCATION` / `CP_CLIENT_COUNTRY` / `CP_JURISDICTION_ID` | `1` / `82` / `82` / `1` | Cashpoint request context.       |
| `SNAPSHOT_PATH`      | `./snapshots/odds-latest.json`                       | Written after every successful refresh (atomic).            |
| `LOG_LEVEL`          | `info`                                               | `debug` \| `info` \| `warn` \| `error`. Logs to stdout/stderr. |
| `REQUEST_TIMEOUT_MS` | `25000`                                              | Per upstream request.                                       |

No secrets are hard-coded; `REFRESH_TOKEN` is the only secret and lives in `.env`
(git-ignored).

---

## Output schema (integration contract)

```json
{
  "source": "merkurbets.de (Cashpoint)",
  "fetchedAt": "2026-07-13T10:00:00Z",
  "stale": false,
  "competitions": [
    {
      "id": "wm",
      "name": "FIFA WM 2026",
      "matches": [
        {
          "id": "wm-2026-07-14-fra-spa",
          "home": "Frankreich",
          "away": "Spanien",
          "kickoff": "2026-07-14T19:00:00Z",
          "venue": null,
          "odds1x2": { "1": 2.30, "X": 3.25, "2": 3.31 },
          "ou25": { "over": 1.87, "under": 1.87 }
        }
      ],
      "outrights": [ { "team": "Frankreich", "odds": 2.50 } ]
    }
  ]
}
```

Rules honoured:

- Decimal odds, dot separator.
- Match `id` = `<competitionId>-<kickoff-date>-<home3>-<away3>`, lowercase ASCII,
  where `<home3>`/`<away3>` are the first three ASCII alphanumerics of the source
  team name with diacritics folded (`Frankreich`→`fra`, `Bayern München`→`bay`).
- Markets not offered are `null` (never guessed). `outrights` is `[]` where none
  are offered.
- Max 10 matches per competition, the next ones by kickoff.
- All six competitions are always present, even in the summer break (empty
  `matches`).

> **Contract note (one deliberate deviation from the prompt's example):** the
> prompt example shows `wm-2026-07-14-fra-esp` for France vs Spain, i.e. the ISO
> code `esp` for Spain. There is no reliable 3-letter code in the feed (club
> teams have none), so the only deterministic, generalizable rule is
> *first-three-letters-of-the-name*, which yields `spa` for "Spanien" →
> `wm-2026-07-14-fra-spa`. If the ARENA side needs ISO codes instead, add a
> lookup table in `src/normalize.js` (`slug3`); flagged here so the mapping is a
> conscious decision, not a surprise.

`venue` is always `null`: the Cashpoint feed carries no stadium/venue field.

Fields whose values are objects — `odds1x2` — serialize with `"1"` and `"2"`
before `"X"` (JavaScript orders integer-like keys first). JSON object key order
is not significant; consumers read by key.

---

## Docker

```bash
docker build -t arena-odds-fetcher .
docker run --rm -p 8080:8080 \
  -e HOST=0.0.0.0 \
  -e REFRESH_TOKEN=your-token \
  -v "$(pwd)/snapshots:/app/snapshots" \
  arena-odds-fetcher
```

Mounting `snapshots/` lets you pull `odds-latest.json` off the host for manual
transfer if the service itself is not reachable from outside.

---

## Project layout

```
arena-odds-fetcher/
├── src/
│   ├── server.js          # HTTP entrypoint + routes + background loop wiring
│   ├── refresher.js       # refresh timing, 60s hard floor, de-dup
│   ├── fetcher.js         # orchestrates one full refresh
│   ├── leagueResolver.js  # competition name -> Cashpoint league IDs (dynamic)
│   ├── cashpointClient.js # read-only HTTP client (headers, timeout, backoff)
│   ├── normalize.js       # pure market/odds parsing -> target schema
│   ├── validate.js        # structural schema validation
│   ├── store.js           # last-good cache, staleness, snapshot writer/seeder
│   ├── config.js          # competitions + fallback league IDs
│   ├── env.js             # .env loader + typed config (60s floor)
│   ├── logger.js          # leveled stdout/stderr logger
│   └── cli.js             # one-off fetch to stdout + snapshot
├── tools/discover.mjs     # OPTIONAL Playwright endpoint-discovery (fallback)
├── test/                  # unit tests + real-data fixtures
├── snapshots/             # odds-latest.json written here
├── DISCOVERY.md           # how the upstream endpoints work (rebuild without this service)
├── Dockerfile
├── .env.example
└── package.json
```

---

## Operational notes / guardrails

- Read-only, public data only. No login, no bet placement, no bypassing of
  technical protections. If the source ever starts blocking read access
  (Captcha/WAF), the service does **not** escalate — it keeps serving the last
  snapshot as `stale` and you fall back to the file-snapshot transfer path (see
  `DISCOVERY.md` §6).
- The 60 s minimum gap between upstream refreshes is enforced in code and cannot
  be lowered by configuration.
- No personal data is read; no cookies are persisted.
