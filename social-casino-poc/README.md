# ARENA — Interaktiver POC (v3: Portrait, Evergreen-Achse, Engagement-Modus)

Klick-Prototyp der Social-Sportsbook-App aus dem [Gesamtkonzept](../social-casino-konzept/01-GESAMTKONZEPT.md), präsentierbar im Browser (eine einzige HTML-Datei, keine Abhängigkeiten). Die v2-Landscape-Version liegt als Archiv in [v2-landscape.html](v2-landscape.html). **Eine native, in Xcode testbare SwiftUI-Version desselben Stands liegt in [../arena-ios/](../arena-ios/).**

## Produktentscheidungen in v3 (09.07.2026)

1. **v2-Pivot bestätigt + Evergreen-Achse ergänzt.** Sport bleibt der Kern, Slots bleiben ein reines Freispiel-Minigame. Die durch den Pivot entstandene Lücke (kein immer verfügbarer Loop, kein Haupt-Coin-Sink) schließen drei neue Systeme:
   - **ARENA Liga** — virtuelle Spiele im ~100-Sekunden-Takt (fiktive Teams, keine Lizenzfragen) mit 1X2/Über-Unter, Live-Quoten-Drift, Markt-Suspendierung bei Toren und Settlement in Sekunden. Auszahlungsquote ~92,5 % ⇒ der Overround ist die neue permanente Coin-Senke. Preisbildung und Simulator sind aneinander kalibriert (kein +EV-Exploit).
   - **Tages-Tipp** — 1 Gratis-Pick pro Tag auf das nächste Liga-Spiel, Serien-Leiter mit eskalierenden Belohnungen (Serie bricht bei Fehltipp oder ausgelassenem Tag).
   - **Stadionausbau** — Meta-Coin-Senke mit Status (4 Ausbauten × 5 Stufen, eskalierende Kosten). **Effekt: +1,5 % Arena Bonus pro Stadion-Level (max +30 %)** — bewusst als Bonus-Boost statt Quotenboost umgesetzt (Quoten bleiben für alle fair, kein Pay-to-Win, Senken-Ökonomie bleibt intakt); Gesamt-Multiplikator (Serie × Stadion) bei ×2,0 gedeckelt.
2. **Portrait-first.** Querformat war ein Präsentationsartefakt des v2-POC; Sportwetten-UX ist Hochformat (einhändig, Second Screen, Wettschein als Bottom-Sheet). Navigation als Bottom-Tab-Bar: Lobby · Sport · Liga · Club · Ich.
3. **Betriebsmodus: Engagement-/Markenprodukt.** Kein Store/Kaufmoment im POC; die Ökonomie zeigt Senken statt Kaufdruck.

## Was der POC zeigt

| System | Umsetzung |
|---|---|
| **Sportsbook** | Reale WM-2026-Viertelfinal-Quoten (Stand 09.07.2026), 1X2 + Über/Unter, Turniersieger, Einzel-/Kombiwetten (2er ab L5, bis 4er ab L12), Spieltags-Simulation **wiederholbar** („Spieltag neu ansetzen" ohne Fortschrittsverlust), Turnier-Simulation settelt Langzeitwetten |
| **Live-Wetten** (ab L10) | Zustandsgetriebene Quoten (nächster Torschütze / kein weiteres Tor), Settlement gegen den echten Simulationszustand, deterministischer **Cash-out** (Anzeige = Auszahlung, fairer Wert aus aktueller Quote − 7 % Marge), Wettannahme schließt ab 85′ |
| **ARENA Liga** | s. o. — Anstoß-Countdown, Live-Minuten, Tor-Suspension, Liga-Tabelle, Wetten zählen für XP/Challenges/Club-Chest |
| **Wett-Engine** | Leg-weises Settlement über alle Markttypen; Void-Legs zählen als Quote 1,0, komplett ungültige Scheine werden erstattet; verwaiste Live-/Liga-Wetten aus alten Sitzungen werden beim Start erstattet; Live-/Liga-Legs werden bei Platzierung zur aktuellen Quote neu bepreist (>5 % Drift ⇒ Schein prüfen) |
| **Einsatz** | Dynamisch per Schieberegler (5.000 bis Max), **Maximum am Spielerlevel gecapt** (je 2er-Levelband ×1,25, Konzept Kap. 6.3) — gilt für Wettschein und Duelle |
| **Tipp-Duell** (nur im Club, ab L8) | Clubmitglied in der Mitglieder-Tabelle antippen ⇒ 1-gegen-1-Wette auf das nächste ARENA-Liga-Spiel: beide Einsätze in den Pot, Gewinner erhält 95 % (5 % Rake als Senke), liegt keiner richtig ⇒ Erstattung; Duell-Liste mit Status im Club-Tab (Konzept Kap. 10.4) |
| **3h-Bonus-System** | Arena Bonus (Coins + 2 Freispiele) mit Countdown-Ring, Level-/Serien-Skalierung (Serie bricht bei Lücken); jeder 3. Claim öffnet **zusätzlich** das Bonus-Rad; Gutschrift atomar beim Claim; unterbrochenes Rad wird beim nächsten Start nachgeholt |
| **Arena Spins (Minigame)** | Canvas-Reels, 5 Gewinnlinien, Win-Celebrations; nur Freispiele, Fest-XP pro Spin |
| **Challenges** | 4 tägliche Aufgaben (Sport, Liga, Bonus, Spins) mit **echter Gutschrift**, Tages-Chest, täglichem Reset |
| **Captain's Six** (ab L20) | Spielbarer 6er-Tippschein, Community-Jackpot (progressiv), Demo-Auswertung |
| **Leveling** | XP = 1,0×Einsatz + 0,25×Nettogewinn (Cap: Gewinnanteil ≤ 5×Einsatz); Multiplikatoren: real 1,2× · live 1,5× · Liga 1,0×; Gates: Kombis L5, Clubs L8, Live L10, größere Kombis L12, Captain's Six L20 |
| **Club / Meta** | Wappen, Wochen-Chest (auch Liga-Einsätze zählen), Mitglieder-Statistiken, Chat, Derby-Teaser; Profil mit Statistiken, Stadion, Abzeichen, Spielerschutz-Hinweis |

## Demo-Regie (für die Kundenpräsentation)

Buttons über dem Gerät: **Bonus sofort bereit** · **+5 Level** · **+1 Mio Coins** · **+10 Freispiele** · **🌅 Neuer Tag** (Challenges/Tages-Tipp-Reset) · **Zurücksetzen**. Spielstand liegt im localStorage (`arena-poc3`).

## Qualitätssicherung v3

Der POC wurde nach dem Neuschreiben durch ein mehrstufiges Review geprüft (Bugfix-Checkliste gegen die 10 dokumentierten v2-Defekte, Runtime-Bug-Jagd, Feature-Logik inkl. Nachrechnen der Quoten-Mathematik, DOM/CSS-Konsistenz). Alle bestätigten Findings sind eingearbeitet, u. a.: Boot-Reihenfolge (kein Crash bei Level-Up während der Orphan-Erstattung), Late-Betting-/Stale-Odds-Schutz (Repricing + Marktschluss 85′/80′), atomare Bonus-Gutschrift, keine gestrandeten Live-Wetten nach „Spieltag neu ansetzen", Render-Signaturen gegen verlorene Taps bei Interval-Rebuilds, Toast-Warteschlange.

## Bewusste POC-Vereinfachungen

- RNG, Wallet, Settlement und Quotenbildung laufen **lokal im Browser** — im Produkt strikt serverseitig (RGS-Muster, Konzept Kap. 18).
- Reale Quoten sind eingebettet (Snapshot); Over/Under-Quoten sind Demo-Werte. „Spieltag neu ansetzen" wiederholt dieselben Paarungen als „Neuauflage".
- Der Tages-Tipp löst im Demo-Kontext über die virtuelle Liga auf (im Produkt: kuratierte reale Picks); ein bei Seiten-Reload offener Tipp verfällt neutral (Serie bleibt).
- Club-Mitglieder/Chat sind simuliert; Sammelalbum nur als Zähler angedeutet.
