# Ökonomie-Simulation — Resume-Anker (Stand 13.07.2026)

Wir bauen A7 (Monte-Carlo-Ökonomie-Simulation). Exakte Formeln aus dem App-Code
(`arena-ios/ARENA/Models/GameState.swift` + `VirtualLeague.swift`) — als Vertrag
für den Simulator (nicht neu recherchieren):

## Faucets
- **Arena Bonus:** `bonusBase = 20000 × 1.10^(min(level,60)-1)`; `bonusAmount = bonusBase × bonusTotalMult`
  - `streakMult = 1 + 0.07×min(streak,7)` (max ×1.49)
  - `stadiumMult = 1 + 0.015×stadiumTotal` (max ×1.30 bei 20 Stufen)
  - `clubStadiumMult = 1 + 0.005×clubStadiumTotal` (max ×1.10)
  - `bonusTotalMult = min(streakMult×stadiumMult×clubStadiumMult, 2.0)`
  - je Claim zusätzlich **+2 Freispiele**; ~3–5 Claims/Tag
- **Special-Rad (jeder 3. Claim):** Coin-EV = 5.0 × `bonusAmount` (Segmente 3×/5×/8×/12×/50× mit Gewichten 26/20/13/9/2, Summe Coin-Gewichte 70; = 490/98=5.0), zusätzlich ~1.79 Freispiele/Dreh + ~0.21 Karten
- **Freispiele → Minigame:** `spinStakeBase = max(10000, 0.5×bonusBase)`; Minigame-EV ≈ **0.4809 × spinStakeBase** pro Freispiel (reiner Faucet, kein Einsatz). Herleitung: weights [27,23,20,14,10,6]/100; pay3 {0:5,1:8,2:12,3:18,4:30,5:60}; pay2 {3:2,4:4,5:8}; 5 Linien; EV-Multiplikator/Linie = Σp_i³·pay3 + Σ_{i∈3,4,5}p_i²(1-p_i)·pay2 = 0.3841+0.0968 = 0.4809; Spin-EV = stake×0.4809. Fest-XP 1500/Spin.
- **Daily Challenges (level-skaliert via `scaled(base)=base×1.10^(min(level,60)-1)`):** bets 60k, virt 40k, bonus 50k, spins 40k; **Tages-Chest** scaled(150k); je Challenge +1 Freispiel, Chest +2
- **Tages-Tipp:** Treffer → `scaled(25000 × min(pickStreak,10))`; Trefferwahrscheinlichkeit ≈ Modellwahrscheinlichkeit des getippten Ausgangs
- **Level-up:** `30000 × 1.08^min(level,60)` Coins + 3 Freispiele je Level
- **Willkommen:** 1.000.000 (einmalig)

## Sinks
- **ARENA Liga:** Hold **7.5 %** des Einsatzes (V_PAYOUT 0.925). Einsatz per Slider, ≤ maxStake.
- **Realsport:** Hold ~5–8 %, nur an Spieltagen.
- **Stadion (persönlich):** Stufe n = `250000 × 2^(n-1)`; 4 Ausbauten × 5 Stufen = **31 Mio** gesamt (Einmal-Sink).
- **Club-Stadion:** `2.500.000 × 2^(n-1)` je Stufe (×10 des persönlichen).
- **Tipp-Duell:** 5 % Rake (Netto-Sink), Pot = 2×Einsatz, Gewinner 95 %.

## Progression / Caps
- **XP-Bedarf:** `xpNeeded(l) = round(20000 × l^1.35)` (kumulativ bis Level l).
- **XP je Wette:** `base + min(0.25×netWin, 5×base)` × mult; mult: Realsport 1.2, Live 1.5, Liga 1.0; Freispiel Fest-XP 1500.
- **maxStake:** `25000 × 1.25^floor((level-1)/2)`, abgerundet auf 5000er, Cap 10 Mio. minStake 5000.

## Design-Ziel (Konzept Kap. 6.2)
Tages-Faucet ≈ **1,05–1,15 × Tages-Burn** des engagierten Non-Payers. Review-Befund:
aktuelle Demo-Werte verletzen das um **Faktor ~4–8** → Simulator soll das quantifizieren
und Skalierungsfaktoren/Launch-Werte je Persona liefern.

## Personas (Vorschlag)
- Engagierter Non-Payer (Zielsegment der Regel): 4 Sessions, ~20 Liga-Tipps/Tag, alle Bonus-Claims (4), alle Challenges, Tages-Tipp, Freispiele genutzt.
- Casual: 1–2 Sessions, ~5 Liga-Tipps, 2 Claims, ~halbe Challenges.
- Whale (Payer): wie engagiert + IAP-Zufluss + höhere Einsätze (Burn-Kapazität-Test).
- Achse: Liga-lastig vs. Realsport-lastig (Spieltagsabhängigkeit).

## Simulator-Plan (`simulate.py`, Python, stdlib)
Tageweise 90 Tage × Monte-Carlo (N Trials) je Persona: Zustand {coins, level, xp, streak,
stadium, freeSpins}; Tages-Faucet & -Burn getrennt tracken; Balance-Trajektorie; Faucet/Sink-
Ratio; dann Tuning-Pass (Faucet-Skalierung suchen, die Non-Payer in 1.05–1.15×Burn bringt) →
`REPORT.md` mit Tabellen + empfohlenen Launch-Werten. Einsatzhöhe modellieren als Anteil des
Level-Max (z. B. 30–50 %), N Tipps/Tag je Persona.
