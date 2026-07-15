# Ökonomie-Simulation — Ergebnis & Launch-Empfehlung (13.07.2026)

Monte-Carlo-Modell (`simulate.py`, 4 Personas × 90 Tage × 200 Trials) mit den
**exakten Formeln aus dem App-Code**. Ziel: den im v3-Review markierten Faucet/Sink-
Befund quantifizieren und Launch-Balancing-Werte ableiten. Reproduzieren: `python3 simulate.py`.

## 1. Befund IST-Zustand (Demo-Werte): die Ökonomie läuft weg

| Persona | Faucet/Tag | Burn/Tag | Ratio | Balance d90 (Median) | Level d90 |
|---|---|---|---|---|---|
| Engagierter Non-Payer | 234 Mio | 6,4 Mio | **36,7×** | **14.923 Mio** | 200 (Cap) |
| Casual | 1,3 Mio | 18 T | 70,6× | 39 Mio | 22 |
| Liga-Junkie | 247 Mio | 16,8 Mio | 14,7× | 18.313 Mio | 200 |
| Whale (Payer) | 248 Mio | 21,3 Mio | 11,6× | 18.855 Mio | 200 |

**Das ist noch drastischer als die Review-Schätzung (4–8×).** Ein engagierter Spieler
sitzt nach 90 Tagen auf ~15 **Milliarden** Coins und ist am Level-Cap. Der Monetarisierungs-
raum existiert nicht — Coins haben keinen gefühlten Wert mehr.

### Wo die Faucets herkommen (Zielsegment, Ø/Tag)
| Quelle | Anteil |
|---|---|
| **Challenges + Tages-Chest** | **40 %** |
| **Bonus-Rad (Special)** | **23 %** |
| Arena Bonus (Basis) | 18 % |
| Tages-Tipp | 9 % |
| Freispiele → Minigame | 9 % |

Wichtig fürs Tuning: Der **Arena Bonus selbst ist nur 18 %** — die größten Hebel sind
**Challenges/Chest** und das **Bonus-Rad**, nicht „der Bonus".

## 2. Zwei strukturelle Ursachen (nicht bloß „Zahlen zu groß")

1. **Exponentielles Faucet-Wachstum:** Faucets skalieren mit `1,10^Level` (Cap L60 = ×253).
   Ein einzelner Bonus-Claim übersteigt bei hohem Level den gesamten Tages-Burn.
2. **Runaway-Leveling:** XP = voller Wett-Turnover → engagierte Spieler erreichen in Wochen
   den Level-Cap und maximieren damit die Faucets. (Konzept wollte „Level 50 nach 2–3 Monaten".)

Ein **reiner Faucet-Regler löst das NICHT**: Der Burn hängt am Einsatzverhalten, und ein
Tagesbonus ist einsatz-*unabhängiges* Grundeinkommen. Ein moderat einsetzender Spieler
akkumuliert immer — genau wie bei Slotomania.

## 3. Empfehlung v1 (strukturelle Fixes) — Wirkung

Konfiguration: Faucet-Wachstum **+4 %/Level** (statt +10 %), Cap **L40**, Bonus-Rad-EV **3×**
(statt 5×), **XP = 12 % des Turnovers** (bremst Leveling), globaler Faucet-Feinregler **0,55**.

| Persona | Balance d90 IST | Balance d90 v1 | Level v1 |
|---|---|---|---|
| Engagierter Non-Payer | 14.923 Mio | **22 Mio** | 15 |
| Casual | 39 Mio | 7,6 Mio | 5 |
| Liga-Junkie | 18.313 Mio | 1,1 Mio | 95 |
| Whale (Payer) | 18.855 Mio | 0,7 Mio | 152 |

**Der Runaway ist gebändigt:** aus 15 Milliarden werden ~22 Mio; das Leveling ist realistisch;
Vielspieler/Whales geraten sogar unter Druck (Ratio ≤ 1 → echter Kaufanreiz).

## 4. Der eigentliche Erkenntnisgewinn: das Design-Ziel muss präzisiert werden

Das Konzept-Ziel „**Faucet ≈ 1,05–1,15× Burn** für den engagierten Non-Payer" ist so **nicht
erreichbar** — selbst mit v1 bleibt das Zielsegment bei ~13× (weil es wenig einsetzt und der
Tagesbonus einsatzunabhängig fließt). Das ist kein Balancing-Fehler, sondern eine falsch
gefasste Kennzahl. **Bessere Steuergrößen:**

- **Gebändigte Balance** statt Ratio: Median-Balance des Zielsegments soll über 90 Tage in
  einem Korridor bleiben (Vorschlag: < 50 Mio), nicht ins Unendliche wachsen. ✅ mit v1.
- **Kaufdruck bei Heavy-Usern:** Vielspieler/Whales sollen Netto-negativ sein (Ratio ≤ 1). ✅ mit v1.
- **Wealth-Sink:** reiche Non-Payer brauchen Coin-Ziele (Kosmetik, Turnier-Buy-ins, höhere
  Stadionstufen, Wager-Anforderungen) — sonst stapeln sich Coins funktionslos.

**Empfehlung an das Konzept (Kap. 6.2 anpassen):** Ziel von „Faucet=Burn" auf
„**gebändigte Balance + Kaufdruck bei Heavy-Usern + Wealth-Sinks**" umstellen.

## 5. Konkrete Launch-Startwerte (Vorschlag zum A/B-Test im Soft Launch)

- Faucet-Wachstum je Level: **+4 %** (statt +10 %), Cap **Level 40**.
- Bonus-Rad-Coin-EV: **3×** des Claims (statt 5×) — größter Einzelhebel nach Challenges.
- **Challenges/Chest** (größter Faucet, 40 %): Beträge ~halbieren.
- XP nur aus **~10–15 % des Turnovers** → Leveling-Tempo „L50 nach ~2–3 Monaten".
- Globaler Faucet-Feinregler **~0,55** als Startpunkt.
- Neue **Wealth-Sinks** in Phase 2 (Kosmetik-Shop, Turnier-Buy-ins) einplanen.

## 6. Grenzen des Modells (ehrlich)

- Faucets deterministisch (Mittelwert), nur Wetten mit Zufall — Balance-Varianz real etwas höher.
- Rettungsleine feuert im Modell bei jedem Balance<Min (Konzept: max. 1×/6h) → Rettungs-Zähler
  der Heavy-User (200–330) ist überzeichnet; qualitativ zeigt er nur „läuft trocken".
- Einsatzverhalten (Anteil des Level-Max) ist angenommen, nicht gemessen — der sensibelste Parameter.
- Kein Club-/Duell-/Geschenk-Kreislauf modelliert (Netto-Transfers, im MVP ohnehin später).

**Nächster sinnvoller Schritt:** Empfehlung v1 als Start-Config in App + Backend übernehmen,
Wealth-Sinks ergänzen, und die exakten Werte im Soft Launch per A/B mit Holdout final justieren
(Konzept-Prinzip). Die Simulation ist die Vorstufe, nicht der Ersatz für Live-Daten.
