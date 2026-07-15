# Deployment: arena-odds-fetcher auf Azure (Germany West Central)

> **Seit 15.07.2026: OFFIZIELLE Integration.** Merkur/Cashpoint haben die
> External-Integration-Doku „Oddsservice v0.5" bereitgestellt (+ Popular League/
> Market IDs). Der Fetcher nutzt jetzt die dokumentierten Parameter: jurisdiction
> 10 (DE-Angebot), WM über Container 283, marketIds-Filter (1X2 + OU 2,5 →
> ~650 Märkte/Spiel auf 2 reduziert), offizielle Liga-IDs als Fallbacks.
> Wichtige Abweichung von der Doku: OHNE die Header `x-location`/`x-client-country`
> kommen Namen als numerische IDs — wir senden weiterhin alle vier Header.
> Der Quoten-Bezug ist damit sanktioniert (Gate G0/Quoten entschärft); die
> formale Vereinbarung + Ergebnis-Feed (A3) bleiben offen.

**Live-Endpoint:** `https://arena-odds-de.azurewebsites.net`
- `GET /health` · `GET /odds` · `GET /odds/{comp}` (comp = wm|bl|pl|ll|cl|dfb)
- Region **Germany West Central (Frankfurt)** — Pflicht, weil der Merkur-/Cashpoint-Feed nur aus Deutschland erreichbar ist. Ein Host außerhalb DE (z. B. West Europe/Amsterdam) würde geo-geblockt.

## Warum diese Architektur
- Der Crawler läuft in DE → der Geo-Block greift nicht mehr.
- Die iOS-App/POC holen die normalisierten Quoten von diesem Server (nicht direkt von Merkur). Damit funktioniert das Testen **von überall** (z. B. iPhone in Italien) — der Server steht in Frankfurt.

## Hosting: Azure Functions (Flex Consumption)
- **Kosten: ~0 €** — Flex Consumption skaliert auf null und liegt im kostenlosen Kontingent (nur wenige Cent Storage/Monat). F1 (Free App Service) ist in dieser Region für die Subscription nicht verfügbar; klassische Linux-Consumption ebenfalls nicht — **Flex Consumption** ist der Weg.
- Kaltstart: erste Anfrage nach Leerlauf dauert ~1–3 s; danach warm.
- Zwei Refresh-Wege: (1) Lazy bei HTTP-Zugriff (>120 s alt ⇒ Hintergrund-Refresh), (2) Timer alle 2 Min.

## Azure-Ressourcen
- Resource Group `arena-odds-rg` · Function App `arena-odds-de` · Storage `arenaodds9e7b45` · alle in `germanywestcentral`.
- Subscription: „Microsoft Partner Network" (JD IT-Consulting).

## Neu deployen (nach Code-Änderung)
```bash
cd arena-odds-fetcher
npm install --no-audit --no-fund          # installiert @azure/functions
zip -qr /tmp/arena-odds-fn.zip host.json package.json functions src snapshots node_modules
az functionapp deployment source config-zip -g arena-odds-rg -n arena-odds-de --src /tmp/arena-odds-fn.zip
```

## Komplett entfernen
```bash
az group delete -n arena-odds-rg --yes
```

## Integration in die iOS-App
`arena-ios/ARENA/Models/OddsService.swift` → Konstante `baseURL`. Die App lädt beim Start `/odds`, mappt in `GameState.competitions`/`liveOutrights` (Fallback: eingebetteter Demo-Snapshot). Status-Anzeige im Sport-Tab: LIVE (grün) / MERKUR gecacht (gold) / DEMO offline (grau).
