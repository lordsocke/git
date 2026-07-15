# ARENA — Native iOS-App (SwiftUI-POC, testbar in Xcode)

Native Umsetzung des [POC v3](../social-casino-poc/) als SwiftUI-App — Sport im Kern, ARENA Liga als Evergreen-Achse, Slots nur mit Freispielen, Engagement-Modus; gleiche korrigierte Spiellogik wie der HTML-POC, aber nativ: Haptik (Core Haptics), SpriteKit-Minigame, echtes iOS-Look-and-feel.

**Orientierung: Landscape-only** (Kundenwunsch nach Review der nativen Variante): Navigation als Icon-Rail links, Zwei-Spalten-Layouts, Wettschein als rechter Drawer, Minigame/Bonus-Rad im Querformat. Der HTML-POC bleibt als Portrait-Variante bestehen — damit existieren beide Orientierungen als vergleichbare Artefakte für die endgültige UX-Entscheidung.

**Quoten:** Als Lieferant ist **Merkur Bets** vorgesehen. merkurbets.de ist außerhalb Deutschlands geo-blockiert (Redirect auf `/restrict/`), daher enthält die App aktuell einen gekennzeichneten Platzhalter-Snapshot (09.07.2026); echte Merkur-Quoten werden nachgezogen, sobald der Abruf aus DE möglich ist.

## Ausführen

1. **Xcode 16 oder neuer** (getestet mit Xcode 26.2), iOS-17-SDK.
2. `ARENA.xcodeproj` öffnen → Scheme **ARENA** → iPhone-Simulator wählen → **⌘R** (im Simulator ggf. ⌘→ zum Drehen — die App rendert ausschließlich Landscape).
3. Für ein echtes Gerät: unter *Signing & Capabilities* ein eigenes Team wählen (Automatic Signing).

Der Build ist verifiziert (`xcodebuild … BUILD SUCCEEDED`, Start + Dauerbetrieb im iPhone-17-Simulator geprüft). Es gibt keine Abhängigkeiten außer Apple-Frameworks (SwiftUI, SpriteKit, Combine).

## Was die App zeigt

- **Lobby**: 3h-Bonus mit Countdown-Ring (Gutschrift atomar, jeder 3. Claim zusätzlich das Bonus-Rad), Tages-Tipp mit Serien-Leiter, ARENA-Liga-Teaser (live tickend), Arena-Spins-Einstieg, Quick-Tipp auf die WM-Spiele, Daily Challenges mit echter Gutschrift, Club-Feed.
- **Sport**: Live-Match mit zustandsgetriebenen Quoten und deterministischem Cash-out (ab L10), vier WM-Viertelfinale (1X2 + Über/Unter), Turniersieger-Langzeitwetten, spielbares Captain's Six (ab L20), „Meine Wetten" mit Leg-Status; Demo-Simulationen (Spieltag, Neuansetzung, Turnier).
- **Liga**: virtuelle Spiele im ~100-Sekunden-Takt mit Anstoß-Countdown, Live-Minuten, Tor-Suspension („Markt gesperrt"), Wettannahme-Schluss ab 80′, Liga-Tabelle. Overround ~8 % als permanente Coin-Senke; Preisbildung und Simulator sind aneinander kalibriert.
- **Club**: Wochen-Chest, Mitglieder-Tabelle, Chat (simulierte Antworten), Derby-Teaser (ab L8). **Tipp-Duell**: Mitglied antippen ⇒ 1-gegen-1-Wette auf das nächste ARENA-Liga-Spiel (Pot = 2×Einsatz, Gewinner erhält 95 %, 5 % Rake als Senke; nur im Club — Konzept Kap. 10.4).
- **Ich**: Statistiken, **Stadionausbau** (Meta-Coin-Senke, 4 Ausbauten × 5 Stufen; Effekt: +1,5 % Arena Bonus je Stadion-Level, max +30 % — bewusst Bonus-Boost statt Quotenboost, Gesamt-Multiplikator ×2,0 gedeckelt), Abzeichen, Spielerschutz-Hinweis.
- **Einsatz**: dynamisch per Slider (5.000 bis Max), Maximum am Spielerlevel gecapt (je 2er-Levelband ×1,25) — im Wettschein und im Duell.
- **Arena Spins**: SpriteKit-Minigame (3×3, 5 Gewinnlinien) — nur Freispiele, Ergebnis steht vor der Animation fest (Server-RNG-Metapher), Fest-XP pro Spin.
- **Demo-Regie**: Zauberstab-Menü oben rechts (Bonus sofort bereit · +5 Level · +1 Mio Coins · +10 Freispiele · Neuer Tag · Zurücksetzen).

## Architektur (POC-Zuschnitt)

- `Models/GameState.swift` — eine `@MainActor`-ObservableObject-Klasse als einzige Wahrheit: Wallet, XP/Level, Bonus, Wett-Engine (leg-weises Settlement, Void-Regeln, Repricing, Orphan-Erstattung), virtuelle Liga, Live-Match, Challenges, Tages-Tipp, Stadion, Captain's Six. Persistenz als JSON in `UserDefaults` (`arena.ios.v3`).
- `Models/VirtualLeague.swift` — Preisbildung (Overround, Poisson-Über/Unter) und Team-Daten der ARENA Liga.
- `Views/` — SwiftUI-Screens (TabView), Wettschein als Bottom-Sheet, Overlays für Bonus/Rad/Big Win, `SlotView` mit SpriteKit-Szene.
- Kein Backend: alles lokal simuliert. Im Produkt sind RNG, Wallet, Quoten und Settlement strikt serverseitig (RGS-Muster, Konzept Kap. 18) — die `GameState`-Methoden markieren die späteren Server-Schnittstellen.

## Bewusste Vereinfachungen gegenüber dem HTML-POC

Partikel-Effekte/Konfetti sind durch Haptik + Animationen ersetzt; das Sammelalbum ist nur ein Zähler; der Club-Chat ist ein einfaches Echo. Die Spiellogik (Formeln, Gates, Senken, Settlement-Regeln) ist identisch mit dem HTML-POC v3.
