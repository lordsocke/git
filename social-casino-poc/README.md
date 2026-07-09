# ARENA — Interaktiver POC

Klick-Prototyp der Social-Casino- & Social-Sportsbook-App aus dem [Gesamtkonzept](../social-casino-konzept/01-GESAMTKONZEPT.md), präsentierbar im Browser (eine einzige HTML-Datei, keine Abhängigkeiten).

## Was der POC zeigt

| System | Umsetzung im POC |
|---|---|
| **Slot-Maschine** | Canvas-Reels mit prozedural gezeichneten Symbolen (Ball, Pokal, Stern, Schuh, Trikot, Pfeife), 5 Gewinnlinien, gestaffelte Win-Celebrations (Big/Mega/Epic Win) mit Coin-Partikeln und Screenshake |
| **3h-Bonus-System** | Arena Bonus mit Countdown-Ring, Levelskalierung und Streak-Multiplikator; jeder 3. Claim öffnet das animierte **Bonus-Rad** (Special Bonus) |
| **Leveling** | XP = 1,0 × Einsatz + 0,25 × Nettogewinn (Cap 5× Einsatz); Level-Gates: Slot 2 ab L5, 2er-Kombis ab L5, Clubs ab L8, Live-Wetten ab L10 |
| **Sportsbook** | Reale WM-2026-Viertelfinal-Quoten (Stand 09.07.2026, aus US-Moneylines umgerechnet), 1X2 + Over/Under, Turniersieger-Langzeitwetten, Wettschein mit Einzel-/Kombiwetten, Spieltags-Simulation, Live-Match mit driftenden Quoten und Cash-out |
| **Club** | Wappen, Wochen-Chest (alle Einsätze zahlen ein), Mitglieder-Statistiktabelle, Chat mit Bot-Antworten, Derby-Teaser |
| **Meta** | Daily Challenges, Profil-Statistiken, Abzeichen, Responsible-Gaming-Hinweis |

## Demo-Regie (für die Kundenpräsentation)

Über dem iPhone-Rahmen liegen vier Regie-Buttons: **Bonus sofort bereit** (überspringt den 3h-Timer), **+5 Level** (zeigt Level-Gates/Club/Live), **+1 Mio Coins**, **Zurücksetzen**. Spielstand wird lokal (localStorage) gehalten.

## Bewusste POC-Vereinfachungen

- RNG, Wallet und Settlement laufen **lokal im Browser** — im Produkt strikt serverseitig (RGS-Muster, Konzept Kap. 18).
- Quoten sind eingebettet (Snapshot), nicht live vom Feed; Over/Under-Quoten sind Demo-Werte.
- Club-Mitglieder/Chat sind simuliert; das Sammelalbum ist nur als Zähler angedeutet.
- Der finale Client ist nativ (SwiftUI + SpriteKit); dieser Prototyp dient der Produkt- und Design-Abnahme.
