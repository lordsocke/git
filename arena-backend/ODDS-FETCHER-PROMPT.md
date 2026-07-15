# Prompt für die Coding-KI auf dem DE-Server: Merkur-Bets-Quoten-Baustein

> Kopiervorlage — Stand 13.07.2026. Ergebnis danach als `arena-odds-fetcher/` ins Repo legen;
> die Integration in App/Backend übernimmt die lokale Session (Schema unten ist der Vertrag).

---

Baue einen eigenständigen **Quoten-Baustein („arena-odds-fetcher")**, der Sportwetten-Quoten von **merkurbets.de** ausliest, in ein festes JSON-Schema normalisiert und als kleiner HTTP-Service bereitstellt. Der Baustein läuft auf diesem Server in Deutschland, weil merkurbets.de außerhalb Deutschlands geo-blockiert ist (302-Redirect auf `/restrict/…`).

## Kontext

- Wir bauen den Prototyp einer Free-to-play-Sportwetten-App („ARENA", nur virtuelle Coins, keine Echtgeld-Funktion). Merkur Bets ist der vorgesehene Quoten-Lieferant; im Endprodukt kommt der Feed hausintern von der Cashpoint-Plattform — dieser Fetcher ist eine **Übergangslösung für den POC**, um echte Quoten-Snapshots zu bekommen.
- Bereits bekannt: merkurbets.de ist eine JavaScript-SPA ohne Quoten im statischen HTML. Das Backend der Seite läuft unter **`https://apiv3-msw-mb-de.cashpoint.solutions`** (JSON-API; der Namespace `/api/v3/…` existiert, antwortet auf falsche Pfade mit `{"status":"fail","message":"Not Found"}`). Die konkreten Endpunkte sind unbekannt — sie sind aus den Netzwerk-Requests der SPA zu ermitteln.
- Es geht ausschließlich um **öffentlich sichtbare Quoten (lesend)**: kein Login, keine Wettabgabe, keine Umgehung von Auth oder Paywalls. Höflich crawlen: gecachte Abrufe, niedrige Frequenz (Standard: 1 Voll-Refresh je 120 s, konfigurierbar), sauberer User-Agent (`arena-poc-odds/1.0`), Backoff bei Fehlern.

## Aufgabe

1. **Endpunkt-Ermittlung:** Öffne `https://www.merkurbets.de` mit Playwright (headless Chromium), zeichne die XHR/Fetch-Requests auf und identifiziere die JSON-Endpunkte für (a) Wettbewerbs-/Event-Listen und (b) Quoten (Pre-Match). Dokumentiere die gefundenen Endpunkte, Parameter und Antwortstrukturen in `DISCOVERY.md`. Wenn die API direkt (ohne Browser) abrufbar ist: bevorzugt direkt abrufen und Playwright nur als Fallback behalten.
2. **Extraktion:** Für die unten gelisteten Wettbewerbe je Spiel: Teams, Anstoßzeit, **1X2-Quoten** und **Über/Unter 2,5 Tore**; zusätzlich, falls angeboten, **Langzeitwetten (Turnier-/Meisterschaftssieger)**. Nicht angebotene Märkte einfach weglassen (Feld `null`), nicht raten.
3. **Normalisierung:** exakt in das Ziel-Schema unten (das ist der Integrationsvertrag — Feldnamen nicht ändern).
4. **Bereitstellung:** Node.js-≥20- oder Python-≥3.11-Service mit:
   - `GET /health` → `{ok, lastFetchAt, stale, source}`
   - `GET /odds` → komplettes Schema-Dokument (aus Cache)
   - `GET /odds/:competitionId` → nur ein Wettbewerb
   - `POST /refresh` → manueller Refresh (mit einfachem Token-Schutz via `.env`)
   - Hintergrund-Refresh alle `REFRESH_SECONDS` (Default 120); bei Fehlern **letzten guten Stand weiter ausliefern** mit `stale: true` und `staleSinceMinutes`.
   - Zusätzlich bei jedem erfolgreichen Refresh einen Datei-Snapshot `snapshots/odds-latest.json` schreiben (für manuellen Transfer, falls der Server nicht von außen erreichbar ist).
5. **Betrieb:** `README.md` mit Setup (npm/pip install, `.env`-Variablen, Start, optionales Dockerfile), Logs auf stdout, keine Secrets im Code.

## Wettbewerbe & ID-Mapping (unsere internen IDs — bitte exakt verwenden)

| competitionId | Wettbewerb bei Merkur Bets |
|---|---|
| `wm` | FIFA WM 2026 (aktuell: Halbfinale/Finale + „Turniersieger“-Langzeitmarkt) |
| `bl` | Bundesliga |
| `pl` | Premier League |
| `ll` | La Liga |
| `cl` | UEFA Champions League |
| `dfb` | DFB-Pokal |

Nicht verfügbare Wettbewerbe (Sommerpause) mit leerem `matches`-Array liefern, nicht weglassen. Team-Namen unverändert übernehmen (deutsche Schreibweise der Quelle).

## Ziel-Schema (Integrationsvertrag)

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
          "id": "wm-2026-07-14-fra-esp",
          "home": "Frankreich",
          "away": "Spanien",
          "kickoff": "2026-07-14T19:00:00Z",
          "venue": "Dallas",
          "odds1x2": { "1": 2.35, "X": 3.20, "2": 3.10 },
          "ou25": { "over": 2.10, "under": 1.72 }
        }
      ],
      "outrights": [
        { "team": "Frankreich", "odds": 2.55 }
      ]
    }
  ]
}
```

Regeln: Quoten als Dezimalzahlen (Punkt als Trenner); `id` = `<competitionId>-<datum>-<home3>-<away3>` (lowercase, ASCII); `outrights` nur wo angeboten, sonst leeres Array; maximal 10 Spiele je Wettbewerb (die nächsten nach Anstoßzeit).

## Leitplanken

- Nur lesende, öffentlich zugängliche Daten; keine Login-/Session-Erzwingung, kein Umgehen technischer Schutzmaßnahmen. Wenn die Seite Abrufe blockt (Captcha/WAF): nicht eskalieren, sondern in `DISCOVERY.md` dokumentieren und den Datei-Snapshot-Weg als primären Modus beschreiben.
- Frequenz-Limit hart einbauen (min. 60 s zwischen Voll-Refreshes, egal was konfiguriert wird).
- Keine personenbezogenen Daten, keine Cookies persistieren über das technisch Nötige hinaus.

## Abnahmekriterien

1. `GET /odds` liefert schema-valides JSON mit mindestens dem Wettbewerb `wm` (solange die WM läuft) und korrekten, gegen die Website stichprobengeprüften Quoten.
2. Service übersteht einen simulierten Ausfall der Quelle (Netz aus → weiter `stale:true`-Antworten, kein Crash).
3. `DISCOVERY.md` dokumentiert die gefundenen Cashpoint-Endpunkte so, dass ein Entwickler den Abruf ohne Playwright nachbauen kann (falls möglich).
4. Ein frischer `snapshots/odds-latest.json` liegt nach dem Start binnen 3 Minuten vor.
5. Kompletter Code + README + Beispiel-Snapshot als ein Ordner `arena-odds-fetcher/` übergebbar.

---

*Danach: Ordner ins ARENA-Repo legen (neben `arena-backend/`) und die Basis-URL bzw. den Snapshot melden — die Integration in iOS-App/POC/Azure-Backend erfolgt lokal (dortiges Schema ist bereits darauf ausgelegt).*
