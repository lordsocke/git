# Merkur Bets Arena — Testanleitung (Stand 14.07.2026)

## Teil A: Die App zu TestFlight bringen (≈ 10 Minuten, einmalig)

Der Build ist **fertig, signiert und liegt in deinem Xcode-Organizer** („Merkur Bets
Arena 1.0 (1)"). Mein automatischer Upload wurde an genau EINER Stelle gestoppt, die
nur ein Mensch mit App-Store-Connect-Zugang erledigen kann: **Der App-Eintrag
existiert noch nicht.** So schließt du es ab:

### Schritt 1 — App-Eintrag in App Store Connect anlegen (2 Min)
1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → mit der Apple-ID
   einloggen, die im **Target-KI-Team** ist.
2. **Apps → „+" → Neue App**:
   - Plattform: **iOS**
   - Name: **Merkur Bets Arena** (falls belegt: „Merkur Bets Arena Beta")
   - Primäre Sprache: **Deutsch**
   - Bundle-ID: **de.targetki.arena** (aus der Liste wählen)
   - SKU: z. B. `merkur-bets-arena`
3. ⚠️ Dafür braucht dein Account die Rolle **App-Manager oder Admin** im Target-KI-Team.
   Wenn die Bundle-ID nicht in der Liste auftaucht oder du den „+"-Button nicht siehst
   → deinen Kontakt bei Target KI bitten, dir die Rolle zu geben (oder den Eintrag
   selbst anzulegen).

### Schritt 2 — Upload (3 Min)
- **Xcode → Window → Organizer → Archives** → „Merkur Bets Arena 1.0 (1)" auswählen
  → **Distribute App** → **TestFlight & App Store** (bzw. „App Store Connect") →
  **Upload** → Automatic Signing bestätigen → fertig.
- Xcode erzeugt dabei automatisch das Distribution-Zertifikat.
- *Alternative:* Sag mir „App-Eintrag ist da" — dann stoße ich den Upload erneut
  per Kommandozeile an.

### Schritt 3 — TestFlight aktivieren (5 Min)
1. App Store Connect → deine App → Tab **TestFlight**. Der Build erscheint nach
   ~5–15 Min Verarbeitung. (Export-Compliance ist im Build schon beantwortet —
   keine Nachfrage.)
2. **Interne Tests** → Gruppe anlegen (z. B. „Kernteam") → dich (+ ggf. Kollegen,
   bis 100 interne Tester) hinzufügen.
3. Auf dem iPhone: **TestFlight-App** aus dem App Store laden → Einladung aus der
   Mail annehmen → **Merkur Bets Arena installieren**. Updates kommen künftig
   automatisch über TestFlight.

> ⚠️ **Namens-Hinweis:** „Merkur Bets Arena" nutzt die Merkur-Marke. Für den
> internen TestFlight-Test unkritisch — vor einem externen/öffentlichen Release
> braucht es die Freigabe von Gauselmann (läuft über euer Rechtsgutachten, Frage 8a).

---

## Teil B: Was du in Build 1 testest

Build 1 ist die **eigenständige App** (Spielstand lokal auf dem Gerät) mit
**echten Merkur-Quoten** aus unserem Frankfurt-Feed. Die Server-Anbindung
(Konten, Server-Wallet — dein „Online-first, frischer Start") kommt als Build 2.

**Fokus deines Tests (Frage 10 aus dem Katalog):**
1. **Ökonomie „Start klein → Millionär":** Du startest mit 1.000 Coins. Fühlt sich
   die erste Stunde gut an? Erster „großer Gewinn"-Moment früh genug? Einsätze
   (Level 1: 10–40) passend?
2. **Live-Quoten:** Sport-Tab → grünes „LIVE"-Badge = echte Merkur-Quoten
   (WM-Halbfinale!). Gold = gecacht, grau = Demo-Fallback.
3. **Shop:** Buttons schalten Coins **kostenlos** frei („Testphase") — kein echtes Geld.
4. **Alles andere:** ARENA Liga, 3h-Bonus + Rad, Freispiele, Challenges, Tages-Tipp,
   Stadion, Club-Demo, Duelle, Live-Wetten ab Level 10.
5. Bonus-Erinnerung: lokale Mitteilung nach 3 h (Push-Erlaubnis beim Onboarding geben).

---

## Teil C: Der Produktions-Server (läuft bereits)

**`https://arena-api-de.azurewebsites.net`** — dein „Ja, push es" von heute Morgen:

| Was | Wo |
|---|---|
| Region | West Europe (Amsterdam) — Germany West Central war für die MPN-Subscription gesperrt; unkritisch, weil nur der Quoten-CRAWLER in DE stehen muss (läuft weiter in Frankfurt) |
| Ressourcen | RG `arena-prod-rg`: PostgreSQL Flexible Server B1ms (`arena-db-de`) + App Service B1 (`arena-api-de`) |
| Kosten | **~25 €/Monat** (13 € DB + 12 € App Service) — etwas über meiner 15–20-€-Schätzung, weil die DB nicht nachts pausiert. Stoppen: `az group delete -n arena-prod-rg` |
| Secrets | JWT/Admin-Key liegen NUR in den Azure-App-Settings (Portal → arena-api-de → Environment variables) |

**Zum Ausprobieren im Browser:**
- `https://arena-api-de.azurewebsites.net/health` — Lebenszeichen + DB
- `https://arena-api-de.azurewebsites.net/matches` — echte Merkur-Quoten aus der DB
- `https://arena-api-de.azurewebsites.net/league/current` — die ARENA-Liga-Runde,
  die gerade serverseitig läuft (alle ~2¼ Min eine neue, Ergebnisse deterministisch
  + auditierbar)
- `https://arena-api-de.azurewebsites.net/outrights` — Turniersieger-Quoten

**Ergebnis-Automatik (deine Vorgabe „suche eine Lösung"):** Der Server holt echte
Endstände von **OpenLigaDB** (kostenlos, deutsche Teamnamen — deckt WM 2026,
Bundesliga, DFB-Pokal) und rechnet Wetten automatisch ab. Ligen ohne Quelle
(Premier League, La Liga, CL) werden nach 48 h ohne Ergebnis automatisch annulliert
und erstattet — ehrlich statt hängend. Sobald der lizenzierte Ergebnis-Feed (A3)
kommt, ersetzt er nur den Provider; die Settlement-Engine bleibt identisch.

---

## Was als Nächstes passiert (Build 2)

Sobald du Build 1 auf dem iPhone hast, verdrahte ich die App mit dem Server
(dein „Online-first mit Lese-Cache" + „frischer Start"): Gast-Konto beim ersten
Start, Server-Wallet, Wetten & Bonus server-autoritativ. Dein lokaler
Build-1-Spielstand wird dabei wie besprochen nicht übernommen.
