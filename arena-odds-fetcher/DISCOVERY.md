# DISCOVERY — merkurbets.de / Cashpoint odds endpoints

**Status:** ✅ The odds feed is reachable **directly over HTTPS** — Playwright is
**not** required at runtime. This document lets a developer reproduce the fetch
with nothing but `curl`/`fetch`.

_Investigated 2026-07-13 from a host inside Germany. merkurbets.de geo-blocks
non-DE clients with a `302 → /restrict/…`; the JSON API hosts below answered
without geo-restriction from the DE host but should be assumed DE-only._

---

## 1. How the site is wired

`https://www.merkurbets.de` is a JavaScript SPA (Angular). It ships a runtime
config file that names every backend:

```
GET https://www.merkurbets.de/environment/web-platform-env.json
```

Relevant fields:

| field              | value                                                | role                                   |
| ------------------ | ---------------------------------------------------- | -------------------------------------- |
| `sportsbookUrl`    | `https://v3-msw-mb-de.cashpoint.solutions`           | embedded sportsbook SPA (iframe host)  |
| `sportsbookApiUrl` | `https://apiv3-msw-mb-de.cashpoint.solutions`        | account / CMS / bonus / ticket API     |
| `translationsUrl`  | `…/api/translation/byprefix?prefix=platform_fe_…`    | UI translations                        |

The **odds** themselves do **not** come from either host above. They come from a
third host that the sportsbook SPA calls:

```
https://oddsservice-msw-mb-de.cashpoint.solutions
```

This was found by loading the site in a headless browser and recording XHR/fetch
traffic (see `tools/discover.mjs`). The three odds endpoints observed were
`getFilters`, `getGames`, and `getHighlightedGames`. We only need the first two.

The trailing `/11` on each path is a fixed channel/skin identifier used by this
white-label; it is constant.

---

## 2. Endpoints we use

All are **`POST`**, body is JSON, no auth, no cookies, no session.

### Required request headers

```
content-type:     application/json
accept:           application/json, text/plain, */*
user-agent:       arena-poc-odds/1.0        (any UA works; we send a clean one)
accept-language:  de-DE
x-system-id:      1
x-language:       1     ← IMPORTANT: makes the server resolve team/league names
                          to German strings. WITHOUT it, `name` fields come back
                          as numeric translation IDs (e.g. 1099511857654).
x-location:       82
x-client-country: 82
```

### 2a. League catalogue — `POST /odds/getFilters/11`

Returns the full filter tree, including the league list used to map competition
names → league IDs.

Request body:

```json
{ "gameTypes": [1, 4, 5], "enableGameCounts": true, "jurisdictionId": 1, "limit": 1 }
```

Response (top-level keys): `time`, `containers`, `sports`, `subcontainers`,
`countries`, `leagues`, `markets`, `bets`.

`leagues[]` entries look like:

```json
{
  "id": 6843,
  "longTerm": false,
  "order": 800,
  "name": "Deutschland Bundesliga",
  "shortName": "Bundesliga",
  "sportId": 1,
  "countryId": 2,
  "prematchGameCount": 9,
  "liveGameCount": 0
}
```

- `sportId: 1` = football.
- `longTerm: true` = an outright / "winner" market league (e.g. `WM 2026 Sieg`).

### 2b. Games + odds — `POST /odds/getGames/11`

Returns games (each with its full market list) for a set of leagues.

Request body (matches):

```json
{ "gameTypes": [1, 4], "leagueIds": [6843], "jurisdictionId": 1, "limit": 20 }
```

`gameTypes`: `1` = pre-match single, `4` = pre-match top/extended, `2` = live
(omitted), `5` = specials. We use `[1, 4]` for matches. Games come back sorted
by `startTime` ascending. Other accepted selectors seen in the wild:
`sportIds`, `gameIds`, `offset`, `groupingPolicy`. (No market-filter parameter
exists — the response always contains every market; the client extracts the few
it needs. `categoryIds`/`marketIds` in the body are silently ignored.)

Game object shape (trimmed):

```json
{
  "id": 3195790822,
  "teams": [
    { "order": 0, "id": 1422, "name": "Frankreich" },
    { "order": 1, "id": 1426, "name": "Spanien" }
  ],
  "startTime": "2026-07-14T19:00:00Z",
  "type": 4,
  "sport": 1,
  "leagueInfo": { "id": 33435, "name": "WM 2026 KO-Phase", "longTerm": false },
  "countryInfo": { "id": 4, "name": "International" },
  "bettingAllowedUntil": "2026-07-14T19:00:00Z",
  "markets": [ /* … see §3 … */ ]
}
```

`team.order === 0` is home, `order === 1` is away. **No venue/stadium field is
present anywhere in the feed** — the target schema's `venue` is therefore always
`null`.

---

## 3. Market & odds model

Each game has `markets[]`; each market has `tips[]`.

- **Odds are integers scaled ×100.** `230` → `2.30`, `100` → `1.00`, `670` → `6.70`.
- A market is identified by `categoryIds`, `subcategoryIds`, `text`, `placeholders`.

### 3a. 1X2 ("Wer gewinnt das Spiel")

The primary full-time result market. `isPrimary: true`, `categoryIds` includes
`1`, `subcategoryIds` includes `1`. Three tips, `text` = `"1"`, `"X"`, `"2"`.

```json
{ "text": "Wer gewinnt das Spiel", "categoryIds": [1], "subcategoryIds": [1], "isPrimary": true,
  "tips": [ {"text":"1","odds":230}, {"text":"X","odds":325}, {"text":"2","odds":331} ] }
```

→ `odds1x2 = { "1": 2.30, "X": 3.25, "2": 3.31 }`

⚠️ Handicap markets (`"Handicap 0:1"`, etc.) **also** carry `1`/`X`/`2` tips.
Exclude any market that has an `hc`/`hcAnchor` field, and prefer `isPrimary`.

### 3b. Over/Under 2.5 goals (full match)

Full-match total-goals family: `categoryIds` includes `2` and **not** `5`,
`subcategoryIds` includes `9`, `text` starts with `"Over + / Under"`.

Two feed variants for the 2.5 line:

- **WM / international feed:** `placeholders: ["2.5"]`, text `"Over + / Under -  2.5"`.
- **Domestic leagues:** `placeholders: []`, line is in the German text: `"Over + / Under - 2,5"` (comma decimal).

So read the line from `placeholders[0]` if present, else parse `\d+[.,]\d+` from
the text, and normalise the comma to a dot.

Tips are labelled by goal ranges, **not** "over"/"under":
`"3+"` = over 2.5, `"0-2"` = under 2.5. (The `+` tip is over, the `n-m` range tip
is under; fall back to tip order `[0]=over, [1]=under`.)

```json
{ "text": "Over + / Under - 2,5", "categoryIds": [1,2], "subcategoryIds": [9], "placeholders": [],
  "tips": [ {"text":"3+","odds":122}, {"text":"0-2","odds":383} ] }
```

→ `ou25 = { "over": 1.22, "under": 3.83 }`

**Exclude the decoys** (all share the "2,5" string): half-time lines
(`categoryIds` contains `5`, `subcategoryIds` `26`/`27`), team-specific lines
(`subcategoryIds` `34`/`35`), and combo bets (`"Beide treffen + …"`,
`"DW: Doppelchance und …"`). The category-2 + subcategory-9 + `^Over + / Under`
text test isolates the correct market.

Note: lower-tier games (e.g. DFB-Pokal first round) legitimately offer **no**
full-match O/U 2.5 — only 1X2/Doppelchance. In that case `ou25` is `null`
(don't guess).

### 3c. Outrights ("Turniersieger" / long-term winner)

These live in a **separate `longTerm: true` league** (e.g. `WM 2026 Sieg`,
id `108895`). Query it like any other league:

```json
{ "gameTypes": [1, 2, 4, 5], "leagueIds": [108895], "jurisdictionId": 1, "limit": 50 }
```

Each "game" is **one team's winner bet**: `teams[0]` is the team, `teams[1]` is a
label ("WM 2026 Sieg"), and there is a single market with a single `"Sieg"` tip.

```json
{ "teams": [ {"order":0,"name":"Frankreich"}, {"order":1,"name":"WM 2026 Sieg"} ],
  "markets": [ { "text": "Siegwette", "tips": [ {"text":"Sieg","odds":250} ] } ] }
```

→ `outrights: [ { "team": "Frankreich", "odds": 2.50 }, … ]`

---

## 4. Competition → league-ID mapping (as of 2026-07-13)

League IDs rotate per season, so the fetcher resolves them **dynamically** by
matching league names from `getFilters` (see `src/config.js` /
`src/leagueResolver.js`). The IDs below are the current values and the hard-coded
fallbacks.

| ARENA id | league name (feed)                    | league id | notes                              |
| -------- | ------------------------------------- | --------- | ---------------------------------- |
| `wm`     | WM 2026 KO-Phase                      | 33435     | matches (semi-finals / final)      |
| `wm`     | WM 2026 Sieg                          | 108895    | outright (Turniersieger), longTerm |
| `bl`     | Deutschland Bundesliga                | 6843      |                                    |
| `pl`     | England Premier League                | 6823      |                                    |
| `ll`     | Spanien La Liga                       | 6938      |                                    |
| `cl`     | UEFA Champions League (Qualifikation) | 19622     | only qualification in summer       |
| `dfb`    | Deutschland DFB Pokal                 | 6847      |                                    |

---

## 5. Reproduce without Playwright

Fetch the league catalogue:

```bash
curl -s https://oddsservice-msw-mb-de.cashpoint.solutions/odds/getFilters/11 \
  -H 'content-type: application/json' -H 'x-language: 1' -H 'x-system-id: 1' \
  -H 'x-location: 82' -H 'x-client-country: 82' \
  --data '{"gameTypes":[1,4,5],"enableGameCounts":true,"jurisdictionId":1,"limit":1}'
```

Fetch Bundesliga games with odds:

```bash
curl -s https://oddsservice-msw-mb-de.cashpoint.solutions/odds/getGames/11 \
  -H 'content-type: application/json' -H 'x-language: 1' -H 'x-system-id: 1' \
  -H 'x-location: 82' -H 'x-client-country: 82' \
  --data '{"gameTypes":[1,4],"leagueIds":[6843],"jurisdictionId":1,"limit":10}'
```

Fetch the WM outright market:

```bash
curl -s https://oddsservice-msw-mb-de.cashpoint.solutions/odds/getGames/11 \
  -H 'content-type: application/json' -H 'x-language: 1' -H 'x-system-id: 1' \
  -H 'x-location: 82' -H 'x-client-country: 82' \
  --data '{"gameTypes":[1,2,4,5],"leagueIds":[108895],"jurisdictionId":1,"limit":50}'
```

---

## 6. If the direct route ever breaks (WAF / Captcha / geo-block change)

1. The direct API showed **no** WAF/Captcha and needed **no** cookies during
   discovery. If that changes and requests start returning `3xx`/`403`/HTML
   challenge pages instead of JSON, **do not escalate** — do not attempt to solve
   challenges or forge sessions.
2. Re-run discovery with the browser to confirm the endpoints/headers:
   `npm install playwright && npx playwright install chromium && npm run discover`.
   It writes an endpoint summary + full response bodies to `tools/discovery-out/`.
3. If the API cannot be reached read-only at all, fall back to the **file-snapshot
   mode**: run the fetcher on a machine that _can_ reach it and hand-carry
   `snapshots/odds-latest.json` to the consumer. The service seeds from that file
   on startup and will serve it (flagged `stale`) until a live fetch succeeds.
