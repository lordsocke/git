# Entscheidungen für den Go-Live — Fragenkatalog (14.07.2026)

Alles, was ich ohne dich erledigen konnte, ist erledigt (Stand siehe unten).
Diese Fragen blockieren jeweils den nächsten Arbeitsschritt. **Kurzantworten
reichen** — z. B. „1A, 2B, 3A, …". Bei jeder Frage steht meine Empfehlung.

---

## 1) Azure-Deployment des Backends — Freigabe? 💶

Das Produktions-Backend (`arena-server/`) ist fertig und getestet, läuft aber nur
lokal. Für deinen iPhone-Test gegen den echten Server muss es nach Azure
(Germany West Central) + eine Postgres-Datenbank.

| Option | Kosten/Monat (ca.) | Beschreibung |
|---|---|---|
| **A (Empfehlung)** | **~15–20 €** | PostgreSQL Flexible Server B1ms (Burstable) + App Service B1. Reicht für Test/Soft-Launch-Vorbereitung, jederzeit skalierbar. |
| B | ~0–5 € | Functions Flex + „Postgres light" (z. B. B1ms mit Stopp über Nacht). Billiger, aber Kaltstarts + Timer-Jobs (Liga-Engine!) passen schlecht zu Serverless. |
| C | 0 € | Noch nicht deployen; erst C2 lokal via Simulator testen. Verschiebt deinen echten iPhone-Test. |

> Die Liga-Engine braucht einen **dauerhaft laufenden** Prozess (Runden-Takt alle
> paar Sekunden) — deshalb rate ich von reinem Serverless (B) ab.

**Deine Antwort:** A / B / C? Falls A: gib mir einfach „A, go" — ich deploye dann in die bestehende Subscription (JD IT-Consulting).

---

## 2) C2-Verdrahtung der iOS-App: Online-Modell?

Wenn die App gegen den Server läuft: Was passiert offline (Flugmodus, Funkloch)?

| Option | Beschreibung |
|---|---|
| **A (Empfehlung)** | **Online-first mit Lese-Cache:** Wetten/Bonus/Spins nur online (server-autoritativ = manipulationssicher); Quoten/Stände werden gecacht angezeigt. Offline sieht man alles, kann aber nichts einsetzen („Offline — nur Ansicht"). Standard bei Sportsbooks. |
| B | Hybrid: offline im lokalen Demo-Modus weiterspielen, online synct. ⚠️ Zwei Ökonomien = Cheat-Tor & viel Aufwand — rate ich ab. |
| C | Hard-Online: ohne Netz nur Splashscreen. Am einfachsten, aber frustig. |

**Deine Antwort:** A / B / C?

---

## 3) Bestehender lokaler Spielstand beim Umstieg auf Server-Konten?

Deine Test-App hat einen lokalen Spielstand (UserDefaults). Nach C2 ist das
Server-Konto die Wahrheit.

| Option | Beschreibung |
|---|---|
| **A (Empfehlung)** | **Frischer Start:** Alle starten neu mit 1.000 Coins auf dem Server. Sauber, kein Migrations-Code für Prototyp-Stände. (Es gibt ja noch keine echten Nutzer.) |
| B | Lokalen Stand einmalig auf den Server übertragen (Coins/XP). Aufwand + Manipulationsrisiko für null echten Nutzen. |

**Deine Antwort:** A / B?

---

## 4) Produktname „ARENA" — final oder Arbeitstitel?

Betrifft: App-Store-Name, Bundle-Display-Name, Logo/Icon, Server-Domains.
„ARENA" ist im App Store stark umkämpft (Namenskollisionen wahrscheinlich);
üblich wäre ein Zusatz.

| Option | Beispiel |
|---|---|
| A | „ARENA" pur versuchen (Kollisionsrisiko bei App-Store-Einreichung) |
| **B (Empfehlung)** | Zusatz festlegen, z. B. „ARENA Sportsclub", „ARENA — Social Sports", „Merkur ARENA" (Marken-Frage!) |
| C | Neuer Name (dann bitte 2–3 Favoriten von dir) |

> ⚠️ „Merkur…" erst nach Klärung mit Gauselmann/Rechtsgutachten (Dachmarke § 5 GlüStV).

**Deine Antwort:** A / B (mit welchem Zusatz?) / C?

---

## 5) TestFlight: Was ist der Stand bei Target KI?

Du wolltest als Developer im Target-KI-Team freigeschaltet werden.

- a) Bist du inzwischen im Team (Einladung angenommen, Team in Xcode sichtbar)?
- b) Signing mit `de.targetki.arena` durchgelaufen (App startet auf deinem iPhone via Xcode)?
- c) Soll ich, sobald (a) steht, den **TestFlight-Upload vorbereiten** (Archive-Build,
  Export-Konfiguration, App-Store-Connect-Metadaten-Checkliste)? Den eigentlichen
  Upload musst du (oder Target KI) auslösen — Apple-Login.

**Deine Antwort:** a) ja/nein · b) ja/nein · c) ja/nein

---

## 6) In-App-Käufe in der Testphase?

Der Shop ist aktuell Demo (Käufe buchen nur lokal Coins). Echte IAP brauchen
App Store Connect-Produkte + Server-Receipt-Validierung (B9).

| Option | Beschreibung |
|---|---|
| **A (Empfehlung)** | TestFlight-Phase **ohne echte IAP** (Shop sichtbar, Kauf = „Demnächst"). B9 kommt vor dem Store-Release. Weniger Review-Risiko, schnellerer Testbeginn. |
| B | IAP sofort echt (Sandbox). Braucht App-Store-Connect-Zugriff + Produkte anlegen (wer? du/Target KI?). |

**Deine Antwort:** A / B?

---

## 7) Push-Notifications („Bonus ist bereit")?

Echte Pushes brauchen einen **APNs-Key (.p8)** aus dem Apple-Developer-Account
(Target KI müsste ihn erzeugen/geben). Lokale Notifications (App erinnert sich
selbst, ohne Server) gehen ohne.

| Option | Beschreibung |
|---|---|
| **A (Empfehlung)** | Testphase: **lokale Notifications** (funktioniert heute schon). APNs erst mit Store-Release. |
| B | Sofort echte Pushes → bitte APNs-Key von Target KI besorgen. |

**Deine Antwort:** A / B?

---

## 8) Externe Blocker — Stand deinerseits?

Kurzer Status reicht (ich kann nichts davon selbst treiben):

- a) **Rechtsgutachten** (Dachmarke/Gauselmann, Arena-Spins-Einordnung): beauftragt? 
- b) **Sportdaten/Ergebnis-Feed** (A3 — WICHTIGSTE LÜCKE: wir haben Quoten, aber keine
  echten *Ergebnisse*; aktuell trägt ein Admin-Endpunkt sie ein): Gibt es einen Draht
  zu Merkur/Cashpoint für einen lizenzierten Feed? Alternativ kommerzieller Anbieter
  (z. B. Sportradar/API-Football, ~50–500 €/Monat) — darf ich einen Test-Account
  eines günstigen Anbieters (API-Football, ~30 €/M) vorschlagen/vorbereiten?
- c) **Apple 18+/Alterseinstufung**: bleibt wie geplant (18+, simuliertes Glücksspiel)?

**Deine Antwort:** a) … · b) … (Test-Anbieter ok?) · c) ja/nein

---

## 9) Clubs & Chat im MVP?

Clubs (Chat, Club-Stadion, Duelle) sind im Prototyp simuliert. ECHTE Clubs mit
echtem Chat brauchen Moderation (EU-DSA/Jugendschutz: Melden, Blocken, Filter,
Mod-Prozess) — das ist Aufwand UND Betriebsverantwortung.

| Option | Beschreibung |
|---|---|
| **A (Empfehlung)** | MVP **ohne** echten Chat: Clubs als Leaderboard + gemeinsames Stadion + Duelle (kein Freitext = keine Moderationspflichten). Chat in Phase 2. |
| B | MVP mit Chat (dann B8 + Moderations-Setup einplanen — Zeit + laufende Kosten). |

**Deine Antwort:** A / B?

---

## 10) Ökonomie: „Start klein → Millionär" nach deinem iPhone-Test bestätigen

Die neue Kurve (Start 1.000, Tag 1 ≈ 2 T, 1 Mio ~ Woche 8) ist eingebaut und
simuliert, aber **du hast sie noch nicht gefühlt**. Nach deinem nächsten Test:

- a) Fühlt sich der frühe Anstieg gut an (erste Stunde / erster Tag)?
- b) Kommt der erste „großer Gewinn"-Moment früh genug?
- c) Einsatz-Slider-Stufen okay (L1: 10–40)?

**Deine Antwort:** Freitext nach dem Test — bis dahin arbeite ich mit den simulierten Werten weiter.

---

# Was ohne deine Antworten bereits fertig ist (Stand 14.07. früh)

**Backend `arena-server/` — Phase B im Kern abgeschlossen, 47/47 Integrationstests grün:**
- **B1 Auth** (Gast + Sign in with Apple + Migration), **B2 Ledger-Wallet** (append-only,
  idempotent, nebenläufigkeitssicher), **B3 Bet-Service + Settlement** (server-autoritative
  Quoten, Kombis, Void, Recovery-Sweep, Auto-Void; adversarial reviewt — 8 Findings gefixt),
  **B5 Liga-Engine** (Poisson-Preisableitung Hold 7,5 %, deterministische Seed-Ergebnisse,
  Audit-Tabelle), **B7 Engagement komplett** (XP/Level aktivitätsbasiert, 3h-Bonus + Serie +
  Rad, Freispiele, Daily Challenges + Chest, Tages-Tipp, Stadion-Sink mit Bonus-Boost,
  **level-gecapptes Max-Stake serverseitig**).
- E2E verifiziert: echte Merkur-Quoten → Wette → Settlement → Auszahlung; Liga-Runde
  → Wette → deterministisches Ergebnis → Auszahlung; Bonus/Rad/Spins/Challenges → Ledger.

**Noch offen in Phase B:** B6 Duelle (hängt teils an Frage 9 — Duelle sind club-gebunden),
B9 IAP (Frage 6), B10 RG-Limits serverseitig (mache ich als Nächstes),
Remote-Config der Ökonomie-Parameter. **B4** (echter Ergebnis-Feed) hängt an Frage 8b.
**C2** (App ↔ Server) hängt an Fragen 1–3 — das ist der große nächste Block.
