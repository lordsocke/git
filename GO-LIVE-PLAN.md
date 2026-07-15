# ARENA — Weg zum Go-Live (Stand 13.07.2026)

Vom aktuellen Prototyp zum produktiven App-Store-Launch. Ehrliche Einordnung:
Der Prototyp ist funktional vollständig, aber **im Kern eine lokale Simulation**.
UI ist ~25–30 % des Wegs; die großen Brocken sind Backend, Recht/Lizenz und eine
echte Ergebnis-/Settlement-Datenanbindung.

Legende Owner: **C** = Claude/Entwicklung · **R** = Richard/Auftraggeber ·
**X** = Extern (Kanzlei, Merkur/Gauselmann, Designer, Apple). **🔴 = harter Blocker.**

---

## 0. Was ist heute echt vs. Demo?

| Bereich | Heute | Für Go-Live nötig |
|---|---|---|
| Quoten (Pre-Match) | ✅ echt (Merkur/Cashpoint, read-only über Frankfurt-Server) | Lizenzierte Datenanbindung statt Crawl |
| Ergebnisse/Settlement echte Spiele | ❌ „Spieltag simulieren"-Button | Echter Ergebnis-Feed → Auto-Settlement |
| Coins/Wallet/Wetten | ❌ lokal (UserDefaults), manipulierbar | Server-autoritativ (Ledger) |
| ARENA Liga | ❌ client-seitig simuliert | Server-Engine (Kern existiert schon) |
| Tipp-Duelle | ❌ Gegner ist ein Bot | Echte Spieler + Server-Escrow |
| Clubs/Mitglieder/Chat | ❌ fest verdrahtet, fake | Echte Accounts, Chat-Backend + Moderation |
| Login | ❌ Apple-Stub / Gast lokal | Echtes Sign in with Apple + Server-Session |
| Coin-Shop | ❌ Demo-Käufe | Echtes StoreKit-2-IAP + Server-Receipt-Check |
| Push | ❌ nur lokale Notifications | APNs serverseitig / CRM |
| Spielerschutz | ⚠️ UI vorhanden, nicht durchgesetzt | Serverseitige Limits, Selbstausschluss-Registry |
| Design/Icon | ⚠️ Platzhalter | Design-System + finales Icon (Designer) |
| Recht/Betreiber | ❌ offen | Gutachten, Marke, Betreiber-Entity, ToS/Datenschutz |

---

## Phase A — Blocker & Grundlagen (überwiegend NICHT Code, jetzt starten)

| # | Aufgabe | Owner | Blocker |
|---|---|---|---|
| A1 | **Auftraggeber/Merkur formal bestätigen (G0)** — trägt Feed, Regulatorik, Marke, Architektur | R/X | 🔴 |
| A2 | **Rechtsgutachten v3** — § 5 GlüStV/Dachmarke, Einordnung Arena Spins / ARENA Liga / Tipp-Duell, Altersverifikations-Pflicht, BFSG, Geo-Liste, DSGVO-Zweckbindung | X (Kanzlei) | 🔴 |
| A3 | **Sportdaten-Vertrag** — 🟡 **Quoten-Seite entschärft (15.07.):** offizielle External-Integration-Doku „Oddsservice v0.5" von Merkur/Cashpoint erhalten und Fetcher darauf umgestellt (jurisdiction 10, Container 283, marketIds-Filter) — der Bezug ist damit sanktioniert, kein Crawl mehr. **Offen bleibt der Ergebnis-/Settlement-Feed** (Zwischenlösung OpenLigaDB läuft) und die formale Vereinbarung | R/X | 🟡 |
| A4 | **Betreiber-Setup** — welche Gesellschaft betreibt/veröffentlicht, ToS, Datenschutzerklärung, Impressum, Auftragsverarbeitungsverträge (Apple, Analytics, Push, Hosting) | R/X | 🔴 |
| A5 | **Marke & Naming** finalisieren (nach Gutachten) — bestimmt Bundle-ID, Store-Eintrag, Assets | R/X | 🔴 |
| A6 | **Apple Developer Program** aktiv (läuft: Freischaltung über Target KI GmbH) | R | 🔴 (für Store/TestFlight) |
| A7 | **Ökonomie-Simulation** (Monte-Carlo) — Konzept-Gate: aktuelle Faucets ~4–8× zu üppig; liefert Launch-Balancing-Werte | C | 🔴 (vor Balancing/Soft-Launch) |
| A8 | Betriebsmodell — Support-, Moderations-, LiveOps-Team, SLAs, Kosten (Opex ist beim Engagement-Produkt die zentrale Business-Case-Größe) | R | — |

---

## Phase B — Produktions-Backend (server-autoritativ)

Das größte Code-Paket. Ohne das ist kein echtes Wallet/keine Integrität möglich.

| # | Aufgabe | Owner |
|---|---|---|
| B1 | ✅ **14.07.** Auth-Service: Sign in with Apple (echt, JWKS) + Gast-Token, Account-Migration — `arena-server/` (Altersverifikations-Hook folgt mit C-Phase) | C |
| B2 | ✅ **14.07.** Wallet/Ledger: Postgres, append-only Buchungssätze, Idempotenz (kein Coins-Feld, sondern Ledger) | C |
| B3 | ✅ **14.07.** Bet-Service + **Settlement-Engine**: server-autoritative Platzierung (Client sendet nur Pick, Server bepreist), Quoten-Ingest (matches + outrights, versioniert), leg-weises Settlement 1X2/OU25, Kombis, Void/Erstattung, Recovery-Sweep + Auto-Void (48 h); adversarial reviewt — 8 bestätigte Findings gefixt, 33 Integrationstests grün | C |
| B4 | 🟡 **Zwischenlösung live 14.07.:** OpenLigaDB-Provider (keyless, deutsche Teamnamen) liefert echte Endstände für WM 2026/Bundesliga/DFB-Pokal → Auto-Settlement alle 10 Min; PL/LaLiga/CL → 48h-Auto-Void (Erstattung). Der lizenzierte Feed (A3) ersetzt später nur den Provider — Settlement-Engine bleibt | C |
| B5 | ✅ **14.07.** ARENA-Liga-Engine serverseitig: Runden-Lebenszyklus über die normale `matches`/Settlement-Maschinerie, exakte Poisson-Preisableitung (Hold 7,5 %), Ergebnis deterministisch aus gespeichertem Seed (Audit/Replay) — WebSocket-Fanout + Live-Quoten im Spielverlauf folgen mit C2 | C |
| B6 | Tipp-Duell-Service: echter Escrow, Annahme-Flow zwischen echten Usern, Collusion-Erkennung | C |
| B7 | ✅ **14.07.** Engagement-Service komplett: XP/Level (aktivitätsbasiert), 3h-Bonus + Serie + Rad (server-gedreht, App-Paritäts-EV 3,05), Freispiele (EV 0,481), **Daily Challenges + Tages-Chest**, **Tages-Tipp** (Auflösung im Liga-Settlement), **Stadion** (Ledger-Sink, Bonus-Boost ×2,0-Cap), **level-gecapptes Max-Stake serverseitig**. Offen: Remote-Config-Anbindung der Parameter | C |
| B8 | Club-/Chat-Service: Mitgliedschaft, Chat, Moderations-Pipeline (Melde-/Block-/Filter), Leaderboards | C |
| B9 | IAP: Server-Receipt-Validierung (App Store Server API), Coin-Gutschrift server-seitig | C |
| B10 | RG serverseitig: Limits, Reality-Checks, Selbstausschluss (dauerhaft, geräteübergreifend), Behavioral Monitoring | C |
| B11 | Push serverseitig: APNs (token-based), Segment-Trigger, CRM-Anbindung | C |
| B12 | Anti-Cheat: App Attest, Rate-Limits, Anomalie-Erkennung, Multi-Account/Farming | C |
| B13 | 🟡 **Basis live 14.07.:** `https://arena-api-de.azurewebsites.net` — App Service B1 + PostgreSQL Flexible B1ms (West Europe; GWC für die Sub gesperrt — nur der Quoten-Crawler muss in DE stehen), Run-From-Package-Deploy, ~25 €/M. Offen: Redis, CI/CD, Monitoring/Alerting, Backup-Politik | C/R |

---

## Phase C — App-Produktreife

| # | Aufgabe | Owner |
|---|---|---|
| C1 | **Alle Demo-Elemente entfernen/gaten**: Demo-Regie-Menü, „simulieren"-Buttons, „(Demo)"-Labels, fester Club „FC Coinkickers", fake Mitglieder/Chat, Demo-Käufe | C |
| C2 | App gegen das echte Backend verdrahten (statt lokaler Simulation): Wallet, Wetten, Liga, Duelle, Clubs, Bonus | C |
| C3 | Echtes Sign in with Apple + Gast-Flow (UI vorhanden, Backend-Anbindung fehlt) | C |
| C4 | Echtes IAP (StoreKit 2) statt Demo-Shop | C |
| C5 | Echte Remote-Push-Registrierung (Device-Token an Backend) | C |
| C6 | **Design-System + finales App-Icon** (Platzhalter ersetzen) | X (Designer) + C |
| C7 | **Orientierung final**: Usability-Test Landscape vs. Portrait, dann eine Richtung sauber ausbauen | R + C |
| C8 | Lokalisierung DE + EN (mind.), sauberes String-Catalog | C |
| C9 | **Barrierefreiheit** (BFSG/EAA): VoiceOver, Dynamic Type, Kontraste, reduzierte Bewegung, nicht-zeitkritische Alternativen | C |
| C10 | Analytics + Event-Taxonomie + Consent (ATT/DSGVO), Amplitude o. ä. | C |
| C11 | FTUE feinschliff, echte Altersabfrage nach Gutachten (A2) | C |

---

## Phase D — QA, Balancing & Härtung

| # | Aufgabe | Owner |
|---|---|---|
| D1 | Balancing mit den Simulations-Werten (A7); A/B-Infrastruktur mit Holdout | C/R |
| D2 | Geräte-Testmatrix (iPhone-Modelle/iOS-Versionen), Regressionstests | C |
| D3 | Lasttest: Settlement-Bursts zum Abpfiff, WebSocket-Fanout, Odds-Ingestion | C |
| D4 | Security-Review + Pentest (Wallet, Auth, IAP, Anti-Cheat) | C/X |
| D5 | Datenschutz-Review (Data-Flow, Zweckbindung, kein Abfluss ins Echtgeld-CRM ohne Rechtsgrundlage) | X/C |

---

## Phase E — Store & Launch

| # | Aufgabe | Owner |
|---|---|---|
| E1 | App Store Connect: App anlegen, Bundle-ID (final aus A5), Privacy Nutrition Labels, **Altersfreigabe 18+**-Fragebogen | R/C |
| E2 | Store-Assets: Screenshots, Beschreibung, Keywords, Support-/Datenschutz-URL | R/C |
| E3 | **TestFlight intern** (sofort nach A6, ohne Review) → Feedback-Runden | R/C |
| E4 | **TestFlight extern** (Beta-Review; hier zählt 18+/Simulated-Gambling — RG-Features müssen sichtbar sein) | C/R |
| E5 | **Soft Launch** in einem Markt (Sportkalender-Fit!), Gate-KPIs messen (D1/D7, Liga-Teilnahme, Ökonomie-Gesundheit) | R/C |
| E6 | Gate-Review → nachtunen oder skalieren → **Go-Live / Phased Release** | R/C |

---

## Realistische Einordnung

- **Harte Blocker sind nicht Code, sondern extern:** ohne A1–A4 (Auftraggeber, Gutachten, Datenlizenz, Betreiber) kein verantwortbarer Launch.
- **Backend (Phase B) ist der größte Aufwand** und der eigentliche Unterschied zwischen „Prototyp" und „Produkt".
- Der **Ergebnis-/Settlement-Feed (A3/B4)** ist eine oft unterschätzte Lücke: Wir haben Quoten, aber keine echten Ergebnisse — aktuell ersetzt durch einen Demo-Button.
- Größenordnung: mehrere Monate mit einem kleinen Team (vgl. Konzept v3 Kap. 21: MVP 6–7 Monate, 9–12 FTE) — der Klick-Prototyp hat den Produkt- und Design-Teil vorweggenommen, nicht den Produktions-Teil.

## Was WIR ohne externe Blocker sofort vorziehen können
1. **Ökonomie-Simulation (A7)** — reines Analyse-Paket, Konzept-Gate, keine Abhängigkeit.
2. **Backend-Fundament (B1–B5)** — Auth + Ledger-Wallet + Settlement + Liga-Engine serverseitig (Liga-Kern existiert bereits als POC-Backend).
3. **Demo-Bereinigung & Beta-Reife (C1, teils C3/C4-Vorbereitung)** — damit der TestFlight-Build sauber ist, sobald der Apple-Account da ist.
