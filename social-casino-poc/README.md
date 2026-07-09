# ARENA — Interaktiver POC (v2: Sport im Kern, Querformat)

Klick-Prototyp der Social-Sportsbook-App aus dem [Gesamtkonzept](../social-casino-konzept/01-GESAMTKONZEPT.md), präsentierbar im Browser (eine einzige HTML-Datei, keine Abhängigkeiten).

## Produktentscheidungen in v2 (Kundenfeedback)

1. **Sport ist der Kern, Slots sind degradiert.** Es gibt keinen Slots-Tab mehr. „Arena Spins" ist ein Bonus-Minispiel als Overlay: **spielbar ausschließlich mit Freispielen** aus dem Arena Bonus (+2 pro Claim), dem Bonus-Rad, Challenges und Level-Ups — **Coin-Einsatz auf Slots ist nicht möglich**. Damit ist das Risiko „Spieler drehen ihr Geld nur noch über Slots" strukturell ausgeschlossen, nicht nur UI-seitig versteckt.
2. **Alles im Querformat.** Landscape-iPhone-Rahmen, Navigation als seitliche Icon-Rail, Lobby/Sport/Club als Zwei-Spalten-Layouts, Wettschein als rechter Drawer, Minigame und Bonus-Rad als Landscape-Overlays.

## Was der POC zeigt

| System | Umsetzung |
|---|---|
| **Sportsbook** | Reale WM-2026-Viertelfinal-Quoten (Stand 09.07.2026, aus US-Moneylines umgerechnet), 1X2 + Over/Under, Turniersieger, Einzel-/Kombiwetten (Kombi ab Level 5), Quick-Tipp direkt in der Lobby, Spieltags-Simulation, Live-Match mit Quoten-Drift, Toren und Cash-out (ab Level 10) |
| **3h-Bonus-System** | Arena Bonus (Coins + 2 Freispiele) mit Countdown-Ring, Level-/Serien-Skalierung; jeder 3. Claim öffnet das animierte **Bonus-Rad** |
| **Arena Spins (Minigame)** | Canvas-Reels mit prozedural gezeichneten Symbolen, 5 Gewinnlinien, Win-Celebrations mit Coin-Partikeln; Gewinnwert skaliert mit Level; nur Freispiele |
| **Leveling** | XP = 1,0 × Einsatz + 0,25 × Nettogewinn (Cap 5×); Sport zählt 1,2×, Live 1,5×; Gates: Kombis L5, Clubs L8, Live L10, Captain's Six L20 |
| **Club** | Wappen, Wochen-Chest, Mitglieder-Statistiken, Chat, Derby-Teaser |
| **Meta** | Daily Challenges (sportfokussiert), Profil-Statistiken inkl. Tipp-Trefferquote, Abzeichen, Responsible-Gaming-Hinweis |

## Demo-Regie (für die Kundenpräsentation)

Buttons über dem Gerät: **Bonus sofort bereit** · **+5 Level** · **+1 Mio Coins** · **+10 Freispiele** · **Zurücksetzen**. Spielstand liegt im localStorage.

## Bewusste POC-Vereinfachungen

- RNG, Wallet und Settlement laufen **lokal im Browser** — im Produkt strikt serverseitig (RGS-Muster, Konzept Kap. 18).
- Quoten sind eingebettet (Snapshot), nicht live vom Feed; Over/Under-Quoten sind Demo-Werte.
- Club-Mitglieder/Chat sind simuliert; Sammelalbum nur als Zähler angedeutet.
- Der finale Client ist nativ (SwiftUI + SpriteKit, Landscape-only); dieser Prototyp dient der Produkt- und Design-Abnahme.
