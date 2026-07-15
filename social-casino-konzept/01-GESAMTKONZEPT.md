# Gesamtkonzept v3: „ARENA" — Social-Sportsbook-App mit Evergreen-Liga (Virtual Currency)

**Arbeitstitel:** ARENA (Platzhalter; Naming nach Markenentscheidung, Kap. 19)
**Auftraggeber:** Internationaler Sportwetten-Anbieter — **unbestätigte Arbeitsannahme: Merkur Bets (Gauselmann-Gruppe)**; Quoten-/Ergebnis-Feed hausintern über die **Cashpoint-Plattform**. *Die Bestätigung dieser Annahme ist Gate G0 vor allen Phase-0-Ausgaben (Kap. 23, Risiko 1).*
**Plattform:** iOS (nativ, SwiftUI + SpriteKit), App Store, 18+ · Landscape als Arbeitsentscheidung (Kap. 16)
**Währungsmodell:** Eine Währung — **Coins** (keine Premium-Währung, kein Cash-out, kein Handel) + **Freispiele** als nicht kaufbare Zweitressource
**Betriebsmodus:** **Engagement-/Markenprodukt** (Kap. 17)
**Stand:** v3 Revision 1, 12.07.2026 — Erstfassung v3 vom selben Tag, überarbeitet nach 4-Perspektiven-Review mit adversarialer Verifikation (~40 bestätigte Findings eingearbeitet) · v1-Archiv: [ARCHIV-01-GESAMTKONZEPT-v1.md](ARCHIV-01-GESAMTKONZEPT-v1.md)
**Referenz-Artefakte:** [POC v3](../social-casino-poc/) (HTML, Portrait) · [Native iOS-App](../arena-ios/) (SwiftUI, Landscape). Beide implementieren die Kernsysteme in Demo-Vereinfachung; **normativ ist dieses Dokument** — wo Artefakte abweichen, ist das je Stelle vermerkt.

---

## Änderungsprotokoll v1 → v3 (Kurzfassung)

| Bereich | v1 | v3 |
|---|---|---|
| Produktkern | Slots als Kern-Loop + Sport | **Sport ist der Kern**; Slots nur Freispiel-Minigame „Arena Spins" (kein Coin-Einsatz) |
| Evergreen-Achse | Slots | **ARENA Liga** (virtuelle Spiele) — übernimmt die *Verfügbarkeits-Rolle* der Slots; die *Frequenz-Rolle* bewusst nicht (Kap. 9) |
| Haupt-Coin-Senke | Slot-Einsätze | Liga-Hold (7,5 % des Einsatzes) + Stadion + Duell-Rake + Club-Gründung + Turnier-Buy-ins (Ph. 2) |
| Betriebsmodus | offen | **Engagement/Marke** — mit Messbarkeits-Auflagen (Kap. 17) |
| Appointment-Layer | 3h-Bonus, Streaks, Challenges | + **Tages-Tipp-Serie** |
| Social | Clubs | + **Tipp-Duell** (Escrow, 5 % Rake, nur Club); Copy-Bet/Tipp-teilen Phase 3 |
| Meta | Album, Kosmetik | + **Stadionausbau** (Senke + Status + Bonus-Boost; kein Quotenboost) |
| Einsätze | Presets | **Slider**, Max am Level gecapt (2er-Bänder ×1,25, abgerundet auf 5.000er) |
| Orientierung | Portrait implizit | **Landscape als Arbeitsentscheidung** + Test-Gate (Kap. 16) |
| Plattform-Weiche | offen | **SwiftUI-first, kein Unity**; Android Kotlin (Timing: Kap. 22) |
| Sportdaten | externer Vertrag (Risiko) | **Cashpoint-Feed hausintern** (unter Merkur-Annahme) |
| Status-Track (VIP-Ersatz) | hebt Bonus ×1,0–1,6 | **Bewusst geändert:** rein kosmetisch/progressiv, KEIN Bonus-Multiplikator (Multiplikator-Budget, Kap. 6.3); Geschenk-Limits bleiben statusabhängig |
| North-Star | „Spins + settled Bets/DAU" | „**settled Coin-Einsätze (Realsport + Liga) + Duelle pro DAU**" (nur Senken-Aktionen; Definition Kap. 21) |

---

## 1. Executive Summary

ARENA kombiniert drei Bausteine in einer Coin-Ökonomie:

1. **Echtes virtuelles Sportsbook** (Pre-Match + Live + Cash-out) auf reale Spiele mit den Quoten des Betreibers (Cashpoint-Feed).
2. **ARENA Liga** — simulierte Spiele fiktiver Teams im ~3-Minuten-Takt: der immer verfügbare Kern-Loop und die Haupt-Coin-Senke (Hold 7,5 %), mit Sofort-Settlement als D0-Dopamin-Anker.
3. **Clubs** — Chat, Chest, Club-Liga, Derby, **Tipp-Duelle** (1-gegen-1 mit Escrow).

Slots existieren nur als Bonus-Minispiel „Arena Spins" (freispiel-only) — die Kundenvorgabe „Guthaben nicht über Slots drehen" ist strukturell erfüllt.

**Ehrliche Einordnung des Reifegrads (aus dem Review):**
- Die **Mechanik** ist in zwei Artefakten prototypisch erprobt; die Liga-Preisbildung ist seit 12.07. **exakt aus dem Simulationsmodell abgeleitet und numerisch verifiziert** (EV je Markt ≈ −7,5 %, Kap. 6.6).
- Die **Balancierung ist offen**: Die aktuellen Demo-Belohnungswerte verletzen die eigene Faucet/Sink-Regel um Faktor ~4–8 (Kap. 6.2) — das Ökonomie-Simulationspaket in Phase 0 ist deshalb ein hartes Gate, kein Begleitprojekt.
- Die **Liga-Taktung** (ein Spiel parallel, ~3-Min-Zyklus) ist als Session-Träger plausibel, aber unvalidiert — Frequenz-/Parallelitätsfragen sind explizit offene Produktentscheidungen (Kap. 9).

**Größte Risiken (Kap. 23):** (1) unbestätigte Merkur-Annahme trägt Feed, Regulatorik-Story und Naming (Gate G0); (2) Ökonomie-Balancierung; (3) Rechtsgutachten v3 (Dachmarke, Liga-/Duell-Einordnung, BFSG); (4) Duell-Collusion.

---

## 2. Produktentscheidungen & Herleitung

| # | Entscheidung (09.–12.07.2026) | Begründung / Status |
|---|---|---|
| E1 | v2-Pivot bestätigt: Sport-Kern, Slots freispiel-only | Kundenfeedback; strukturell statt kosmetisch umgesetzt |
| E2 | ARENA Liga als Ersatz-Achse | Deepdive: Pivot entfernte Minuten-Loop + Haupt-Sink (Faucet/Sink-Lücke Faktor ~15). Liga = sport-authentische Antwort. *Ersetzt die Verfügbarkeit, nicht die Slot-Frequenz — Kap. 9* |
| E3 | Engagement-Modus | Ohne Slot-Burn kein Casino-ARPDAU; Markenbindung als Primärzweck. *Auflage: messbar machen (Kap. 17), sonst nicht steuerbar* |
| E4 | Landscape — **Arbeitsentscheidung** | Kundenpräferenz nach Gerätetest. Bindend für die Prototypen; **final erst nach Usability-Test mit vorab definierten Kriterien** (Kap. 16) — beide Orientierungen existieren als Artefakte |
| E5 | Stadion = Bonus-Boost, kein Quotenboost | Quotenboost = Senken-Schwächung + Pay-to-Win + „kaufbare Gewinnchancen" (regulatorisch/reputativ heikel) |
| E6 | Tipp-Duell nur im Club | Kundenwunsch; präzisiert v1 Kap. 10.4; Club-Bindung als Voraussetzung |
| E7 | Einsatz-Slider, Level-Cap | Kundenwunsch; implementiert v1-Einsatz-Progression sichtbar |
| E8 | Quoten: Merkur Bets/Cashpoint | Kundenvorgabe; **gilt nur unter der Merkur-Annahme — Gate G0**; Plan B: Sportradar/Genius (F2P-Klausel, Kosten/Dauer ungeklärt) + separate Marke |
| E9 | Kein Unity; Android Kotlin | Slot-Core ist Overlay-Modul; >90 % Standard-UI. *Android-Timing neu abzuwägen — Engagement-Ziel DE braucht Android-Masse (Kap. 22)* |

### 2.1 Positionierung & was wir bewusst NICHT bauen (aus v1 übernommen, v3-aktualisiert)

> **„Die Arena für Sportfans: Tippen, Liga, Teamgeist — ohne echtes Geld zu riskieren."**

- Gegen Fliff/Rebet: vollwertiges Meta (Liga, Bonus, Stadion, Clubs) statt reinem Sweepstakes-Sportsbook.
- Gegen Social Casinos: Sport-Authentizität statt Slot-Ästhetik; ehrliche Ein-Währungs-Ökonomie.
- **Nicht bauen:** kein Sweepstakes-/Redemption-Modell (US-Verbotswelle), kein Cash-out/Handel, keine Echtgeld-Brücke, **keine Energie-Drossel für den Kern-Loop** (Liga & Sportsbook sind coin-gedrosselt; die Freispiel-Bindung von Arena Spins ist zulässig, weil das Minigame bewusst *kein* Kern-Loop ist), keine kaufbaren Gewinnchancen-Ressourcen jeder Art (Freispiele, Free-Bets, Boosts).

---

## 3. Produktstruktur & Navigation

Fünf Bereiche über die Icon-Rail (Landscape-Chrome), Inhalte zweispaltig, Wettschein als Drawer:

```
┌──────┬────────────────────────────────────────────────┬ ─ ─ ─ ─ ┐
│ RAIL │  HUD: Level·Rang · Freispiele · Coins          │ WETT-   │
│ Lobby├────────────────────────────────────────────────┤ SCHEIN  │
│ Sport│  LOBBY: Bonus-Hub · Tages-Tipp · Liga-Teaser · │ (Drawer)│
│ Liga │         Arena Spins · Quick-Tipp · Challenges  │  Slider │
│ Club │  SPORT: Live · Spieltag · Langzeit · C6 · Bets │  Einsatz│
│ Ich  │  LIGA:  Spiel · Tabelle                        │  ≤ Cap  │
│      │  CLUB:  Chest · Mitglieder(→Duell) · Chat      │         │
│      │  ICH:   Statistiken · Stadion · Abzeichen · RG │         │
└──────┴────────────────────────────────────────────────┴ ─ ─ ─ ─ ┘
```

**Quick-Tipp** (Lobby): 1X2-Schnellauswahl an den Realspiel-Zeilen — legt die Auswahl direkt in den Wettschein. Die Lobby zeigt immer den nächsten erreichbaren Vorteil; in der Liga läuft immer gleich das nächste Spiel an.

---

## 4. Zielgruppen & Segmentierung

Wie v1 (Sportfan · Casual · Sozialer · Wettbewerbsspieler; Spending-/Engagement-/Affinitäts-Segmentierung), mit v3-Achse **Liga-lastig vs. Realsport-lastig**. Der Casual wird über die niederschwellige Liga geholt (tippen statt drehen), der Wettbewerbsspieler über Duelle und Trefferquoten-Identität.

---

## 5. Core Loops v3

### 5.1 Minuten-Loop — ARENA Liga

```
Anstoß-Countdown (~30 s) → Tipp (1X2/Ü-U, Coins, Slider ≤ Level-Cap)
→ ~2,5 Min Live-Verlauf im Zeitraffer (Tore, Quoten-Drift, Suspendierung)
→ Schlusspfiff → Sofort-Settlement: ±Coins, XP, Club-Punkte, Challenges
→ nächstes Spiel → noch ein Tipp        [Zyklus gesamt ~3 Min]
```
Jeder Einsatz zahlt auf vier Systeme ein (Kontostand, XP, Club, Challenges) — auch Verlust-Sessions erzeugen sichtbaren Fortschritt. Liga-Cash-out: Phase 2 (Kap. 9). *Demo-Artefakte laufen beschleunigt (~100-s-Zyklus).*

### 5.2 Stunden-Loop — Bonus & Realsport

3h-Bonus → Claim mündet in unmittelbaren Handlungs-Hook (Quick-Actions: Freispiele nutzen / zur Liga) → kurze Session → Live-Spiel/Settlement-Push → Wiederkehr.

### 5.3 Tages-Loop

Daily Challenges (4 Aufgaben, einzeln gutgeschrieben + Tages-Chest) · **Tages-Tipp** (1 Gratis-Pick, Serien-Leiter) · Club-Check-in · Stadion-Fortschritt.

### 5.4 Wochen-Loop

Club-Chest & Club-Liga (Mo–So) · Captain's Six (Deadline Spieltag) · **Wochenbogen** (7 Claim-Schlüssel → Wochen-Truhe) · Duell-Wochenbilanz.

### 5.5 Season-Loop

**Liga-Saisons** (2 Wochen, Tabellen-Reset + Zeremonie + Saison-Badges): **Phase 2**. Große Seasons (6–8 Wochen, Belohnungsleiste, Album, Sportkalender-Kopplung): **Phase 3**. Im MVP läuft die Liga-Tabelle fortlaufend ohne Reset.

---

## 6. Coin-Ökonomie v3

### 6.1 Grundsätze

Wie v1 (kein Realwert; Spielen immer möglich — 24/7-Liga + Rettungsleine als Big-Fish-Verteidigung; nicht kaufbare Fortschrittsachsen). **Freispiele** sind eine getrennte Wallet-Ressource und tauchen in keinem Kaufangebot auf.

### 6.2 Faucets & Sinks — und der ehrliche Befund

> Werte in der Tabelle = **Level-1-Anker** der „Start klein → Millionär"-Skala (Start **1.000 Coins**). Alle Faucets wachsen mit **+11 %/Level** (Cap L55) über die Progression um ~1000× mit; der Max-Einsatz wächst mit **+16,5 %/Level** bewusst schneller.

| Quellen (L1-Anker, wachsen mit Level) | Senken |
|---|---|
| Willkommenspaket **1.000** (einmalig) | **Liga-Hold: 7,5 % des Liga-Einsatzes** (Auszahlungsfaktor 0,925; Overround 8,1 % ist die Quoten-, nicht die Umsatzgröße) |
| Arena Bonus (3h): Basis **60 × 1,11^(min(L,55)−1)** × Multiplikator (Cap ×2,0) | Realsport-Hold (~5–8 %, spieltagsgebunden) |
| Special-Rad jeder 3. Claim: **EV ≈ 3 × Claim-Betrag** (Segmente 2/3/5/8/25×) **+ Ø 1,79 Freispiele + 0,21 Karten je Dreh** | **Stadion:** Stufe n kostet 250 × 2^(n−1) (Vollausbau ~15 T) — bewusst früh abschließbarer Meilenstein; echte Wealth-Sinks (s. u.) in Phase 2 |
| +2 Freispiele je Claim (EV je Freispiel ≈ 0,24 × Bonus-Basis; Tages-EV ≤ 10–15 % des Budgets) | **Duell-Rake 5 %** des Pots |
| Tages-Tipp: **40** × min(Serie, 10) je Treffer (level-skaliert) | **Club-Gründung: 500** (einmalig, ab L20) |
| Daily Challenges 4 × **35–50** + Tages-Chest **120** (level-skaliert) | Turnier-Buy-ins + 10–15 % Rake (Phase 2) |
| Level-up: **300 × 1,11^(min(L,55)−1)** + 3 Freispiele | Kosmetik · Challenge-Reroll · Streak-Repair (1×/Woche) |
| C6-Preise · Club-Ausschüttungen · Geschenke (Empfangs-Cap/Tag) | — |
| Wett-/Duell-Gewinne (Rückfluss) · IAP | — |

**Referenz-Burn:** skaliert mit dem Level (Einsatz × Tipps × 7,5 % Hold). Weil der Max-Einsatz schneller wächst als die Faucets, holt der Burn mit steigendem Level auf ⇒ die Balance klettert erst stark und plateaut dann in den Millionen (s. Trajektorie unten).

> **Befund (Review, bestätigt):** Die ursprünglichen Demo-Belohnungswerte verletzten die Design-Regel massiv; **die Monte-Carlo-Simulation (13.07.2026, `arena-economy-sim/`) hat es quantifiziert:** engagierter Non-Payer Faucet/Burn **36,7×**, Balance nach 90 Tagen ~15 **Milliarden**, Level-Cap in Wochen. Größte Faucets: **Challenges/Chest 40 %, Bonus-Rad 23 %** (der Bonus selbst nur 18 %). Ursachen strukturell: exponentielles Faucet-Wachstum (1,10^Level) + Runaway-Leveling (XP = voller Turnover).

> **Zwischenschritt (verworfen):** Ein erster Fix (Bonus +5 %/L40, Rad-EV 3×, Challenges halbiert, Start weiter 1 Mio) bändigte zwar die Inflation (d90 ~23 Mio statt 15 Mrd.), lieferte aber kein **Progressionsgefühl** — man startet als „Millionär" und bleibt einer.

> **Finales Design „Start klein → Millionär" (umgesetzt 13.07., App + POC + Sim):** Start **1.000 Coins**; alle Faucets +11 %/Level (Cap L55), Max-Einsatz +16,5 %/Level. Zusätzlich **XP von Coins entkoppelt** → Leveln nach **Aktivität** (feste Punkte je Handlung), nicht nach Einsatzhöhe. Das war nötig (bei kleinen Coins würde einsatzbasierte XP das Leveln blockieren) und beseitigt zugleich das alte Leveling-Runaway. Validiert (`arena-economy-sim/tune_startsmall.py`): engagierter Non-Payer klettert **1.000 → 1 Mio um Tag ~60 (Woche 8–9)** → mehrere Mio im 3. Monat; Level-Pacing **L8 ~Tag 4, L20 ~Tag 20, L50 ~Tag 100**; Heavy-User (Liga-Junkie/Whale) bei Ratio **~1,2–1,5×** (Kaufdruck). Bestehende Prototyp-Stände werden per Schema-Version einmalig auf die neue Skala zurückgesetzt.

> **Design-Ziel (präzisiert):** „Faucet ≈ Burn" ist als Kennzahl verworfen. Steuergrößen sind jetzt: (1) **Progressions-Trajektorie** — Zielsegment erreicht „1 Mio" in einem definierten Korridor (Woche 6–10), danach **Plateau** statt Weiterwuchern (getragen vom schneller wachsenden Max-Einsatz + Wealth-Sinks) · (2) **Netto-Druck bei Heavy-Usern** (Ratio ~1) · (3) **Wealth-Sinks** für den Millionen-Bereich (Kosmetik, Turnier-Buy-ins, höhere Stadionstufen — Phase 2), weil das level-skalierte Stadion allein den High-Level-Sink nicht mehr trägt. Feinjustierung final per Soft-Launch-A/B mit Holdout. Dashboard/KPIs (Kap. 21) entsprechend.

### 6.3 Multiplikator-Budget

Bonus-Multiplikatoren: Bonus-Serie ×1,07 (Tag 1) → ×1,49 (Tag 7+) · Stadion bis ×1,30 · Club-Liga-Division +2 %/Division (Phase 2). **Gesamt-Cap ×2,0.** Der Status-Rang ist in v3 bewusst **kein** Bonus-Multiplikator (Abweichung von v1, s. Änderungsprotokoll).

### 6.4 Inflationskontrolle

Einsatz-Progression als impliziter Sink (Max-Einsatz wächst schneller als Bonus-Basis) · statistische Undichtheit des Sport-Holds (Strähnen) wird durch den hochfrequenten, exakt kalibrierten Liga-Hold + Stadion + Rake aufgefangen · Geschenk-Empfangs-Cap · Kurzform-Zahlen ab Tag 1.

### 6.5 Rettungsleine

Trigger: Balance < 5.000 (Mindesteinsatz). Inhalt: 2–3 Mindesteinsätze + 5–10 Freispiele. Kadenz: alle **6 Stunden** (Remote-Config-Parameter), Missbrauchs-Pacing für Serien-Buster. Durch die 24/7-Liga gilt „binnen Minuten wieder spielfähig".

### 6.6 Kalibrier-Invariante der ARENA Liga (ökonomiekritisch — implementiert & verifiziert)

**Quoten werden exakt aus dem Simulationsmodell abgeleitet** (Tore ~ Poisson(λ · Restzeit) mit λ ≈ 2,685, Heimanteil q aus Teamstärken; Ausgangswahrscheinlichkeiten per Poisson-Splitting über Endstände; Quote = 0,925/p). Damit ist der EV je Markt konstruktionsbedingt −7,5 % (modulo Rundung/Clamps). **Preisheuristiken sind verboten.** Status: In beiden Prototypen seit 12.07.2026 exakt implementiert und per Monte-Carlo verifiziert (400.000 Simulationen je Konstellation: EV aller Märkte −7,0 % bis −8,0 %). Im Produkt ist diese Prüfung ein **CI-Test der Liga-Engine**; dazu auditierbarer RNG und deterministische Replays je Spiel (Seed + Modellversion).

---

## 7. Leveling, Einsätze & Progression

### 7.1 XP-Formel

```
XP = (1,0 × Einsatz + 0,25 × Nettogewinn[Gewinnanteil ≤ 5 × Einsatz]) × Mult
Mult: Realsport 1,2 · Live 1,5 · Liga 1,0 · Duell 1,0
Fest-XP: Freispiel-Spin 1.500 · Tages-Tipp-Treffer 10.000 · C6 20.000 · Stadion Kosten/20
FTUE-Fest-XP: geführte Onboarding-Schritte geben Fest-XP (Stellschraube fürs D0-Pacing, Kap. 14)
```
Exploit-Schutz wie v1 + Liga-XP-Tagesvolumen-Cap.

### 7.2 Levelkurve, Pacing & Freischaltungen

Kurve: 20.000 × Level^1,35. **Pacing (rechnerisch geprüft):** Session 1 → Level 3–4 (per FTUE-Fest-XP auf 4 hebbar); Tag 2–4 → Level 8; Level 20 ≈ Woche 2–3; **Level 50 nach ~2–3 Monaten** (Liga-Volumen-abhängig — Simulation kalibriert). **Meilenstein-Level 25/50/100:** großes Paket + permanentes Badge + Club-Broadcast (soziale Sichtbarkeit, aus v1 übernommen).

| Level | Freischaltung (MVP) | ab v1.0 |
|---|---|---|
| 1 | Realsport (Einzel), Liga, Tages-Tipp, Bonus, Arena Spins | — |
| 3 | Daily Challenges | — |
| 5 | 2er-Kombis | — |
| 8 | **Freundesliste + Geschenke** (MVP-Sozialschicht) | **Club-Beitritt + Duelle** (ersetzt/erweitert die Freundesliste) |
| 10 | Live-Wetten Realsport + Cash-out | — |
| 12 | Kombis bis 4er | — |
| 20 | Captain's Six | + Club-Gründung (500-T-Gebühr) |
| 30+ | — | Turnier-Klassen, Kosmetik, Prestige |

**Freundesliste (MVP, minimal spezifiziert):** Hinzufügen per Einladungscode/Kontakten; 1 Coin-Geschenk/Tag je Freund (levelskaliert, Empfangs-Cap); Datenmodell-Entität `Friend` in Phase 1 (Kap. 20.3) — wird in v1.0 zur Club-Mitgliedschaft migriert.

### 7.3 Einsatz-Progression

Min 5.000 · **Max = 25.000 × 1,25^⌊(Level−1)/2⌋, abgerundet auf 5.000er** (beide Artefakte identisch), global 10 Mio. Slider mit Max-Aktion; Cap serverseitig durchgesetzt. **Status-Track:** Saison-Rang (Bronze→Diamant) aus Aktivität — kosmetisch + Geschenk-Limits, kein Bonus-Effekt (6.3).

---

## 8. Bonus-System v3

- **Höhe:** Basis 20.000 × 1,10^(min(L,60)−1) × min(Bonus-Serie × Stadion [× Club-Liga-Division ab v1.0], 2,0). **Bonus-Serie:** ×1,07 (Tag 1) bis ×1,49 (Tag 7+), Formel 1 + 0,07 × min(Tage, 7); bricht bei Kalendertag ohne Claim; Streak-Repair 1×/Woche. Jeder Claim +2 Freispiele.
- **Atomarität:** Gutschrift im Claim-Moment; Overlay rein zelebratorisch; ausstehendes Rad wird persistiert und nachgeholt.
- **Special additiv:** 3. Claim = Basis + Freispiele **und** Rad (EV-Budget s. 6.2); Ring verfällt nie.
- **Akkumulation** bis 6 h (1,5 Fenster) und **Wochenbogen** (7 Claim-Schlüssel → Wochen-Truhe) aus v1 übernommen (Produkt-Spec; in den Demo-Artefakten nicht umgesetzt).

*Terminologie: „Bonus-Serie" (Claims), „Tipp-Serie" (Tages-Tipp) und „Wochenbogen" (Schlüssel) sind drei getrennte Systeme und werden im UI so benannt.*

---

## 9. ARENA Liga

**Rolle (präzisiert):** Die Liga übernimmt die *Verfügbarkeits-Rolle* der v1-Slots (24/7 bespielbarer Kern-Loop, Haupt-Senke, Sofort-Settlement). Sie ersetzt **nicht** die Slot-*Frequenz* (Handlung alle 2–4 s) — das ist Absicht (kein Slot-Kompulsions-Klon), aber damit ist offen, ob ein Einzelspiel im 3-Minuten-Takt 8–12-Minuten-Sessions trägt. **Offene Produktfragen für Soft-Launch-Experimente:** (a) 2–3 parallele Spiele mit versetztem Anstoß, (b) Markttiefe (nächstes Tor, Handicap), (c) Taktung 2–4 Min. Die Session-Ziel-KPIs werden bis dahin nicht auf die Liga allein gerechnet.

- **Format:** 8 fiktive Teams (lizenzfrei), fortlaufende Paarungen; **Zyklus ~3 Min** (Spielverlauf ~2,5 Min Zeitraffer, Pause ~30 s); Tabelle; **Saisons (2 Wochen) ab Phase 2**.
- **Märkte:** 1X2, Über/Unter 2,5. Preisbildung: Kap. 6.6 (exakt, Hold 7,5 %). Live-Drift folgt Spielstand/Restzeit aus demselben Modell; **Suspendierung bei Toren** (~2,5 s, offene Auswahlen verworfen); **Annahmeschluss 80.'**; Repricing bei Platzierung (Kap. 10).
- **Cash-out (Liga): Phase 2** — gleiches deterministisches Pricing wie Realsport (Kap. 10); bis dahin sind Liga-Wetten bis zum Settlement gebunden. Liga-Selektionen sind mit Realsport kombinierbar (leg-weises Settlement macht das sauber); Duelle sind immer Einzel.
- **Integrität & Transparenz:** auditierbarer RNG, Replays, Ergebnis-Historie einsehbar, Auszahlungsquote (92,5 %) offen im UI.
- **Verzahnung:** XP 1,0× · Club-Chest/-Liga · Challenges · Tages-Tipp · Duelle · Blitz-Turniere (Phase 2, Buy-in + Rake).
- **RG:** Reality-Checks/Limits greifen ausdrücklich für die Liga (Kap. 18); keine dramatisierten Fast-Gewinne — der Verlauf folgt dem ehrlichen Modell.

---

## 10. Echtes Sportsbook (Realsport)

- **Feed:** Cashpoint (unter G0); Klärung Mandanten-Trennung F2P/RMG (Apple 5.3.3), SLA, Markt-/Sportartenabdeckung je Zielmarkt. Fallback: Sportradar/Genius (F2P-Klausel, Kosten offen — Risiko 1).
- **Angebot:** kuratierte Top-Märkte; **Sportarten marktabhängig**: DACH Fußball-zentriert; Soft-Launch-Märkte brauchen NHL/NBA/NFL bzw. lokale Ligen (Feed-Abdeckung in Phase 0 prüfen — Kap. 22). Langzeitwetten; Einzel/Kombi nach Gates.
- **Live + Cash-out (ab L10, MVP):** zustandsgetriebene Quoten; Cash-out deterministisch (fairer Wert × 0,93; Cap 0,95 × möglicher Gewinn; Anzeige = Auszahlung); Annahmeschluss 85.'. *Hinweis FTUE: Live ist hinter L10 — im Onboarding wird es als sichtbarer, gesperrter Teaser gezeigt, damit der Kern-USP nicht unsichtbar bleibt (Kap. 14).*
- **Settlement leg-weise:** won/lost/void je Leg; Kombi verliert beim ersten Lost-Leg; **Void = Quote 1,0**; alles void = Erstattung; verwaiste Legs (abgesagte Events) werden erstattet. **Repricing:** Live-/Liga-Legs zur aktuellen Quote; > 5 % Drift ⇒ Schein zur Bestätigung zurück.
- **Keine Echtgeld-Brücke** (CTAs, Links, geteilte Guthaben) — unverändert.

---

## 11. Appointment-Layer

- **Tages-Tipp:** 1 Gratis-Pick/Tag auf das nächste Liga-Spiel. **Zweck: tägliches Ritual mit Sofort-Feedback und Serien-Druck** — ausdrücklich *kein* „zweiter Tagesbesuch"-Mechanismus (Review-Korrektur). Belohnung 25.000 × min(Tipp-Serie, 10); Serie bricht bei Fehltipp oder ausgelassenem Tag; nicht zu Ende geschauter Pick verfällt neutral (Tag verbraucht, Serie bleibt). *Produkt-Option für Spieltage: zusätzlicher kuratierter Real-Pick mit später Auflösung — der ist dann der Rückkehr-Anker.*
- **Daily Challenges:** „2 Tipps" = settled **Coin-Einsatz-Wetten beliebiger Art** (Realsport oder Liga; der Gratis-Tages-Tipp zählt nicht) · „1 Liga-Wette" (zählt zugleich als Tipp — bewusste Überlappung als Liga-Nudge) · „2 Bonus-Claims" · „5 Freispiele". Einzeln sofort gutgeschrieben; alle 4 = Tages-Chest.
- **Captain's Six (ab L20):** 6 Paarungen/Woche; progressiver Community-Jackpot (12,5 Mio + 2,5 Mio/Woche), 5/6 = 1 Mio, 4/6 = 250 T; Club-Wertung ab v1.0.

---

## 12. Clubs, Duelle & Social Betting

Club-Grundgerüst aus v1 Kap. 9 (50 Mitglieder, Rollen, Chest → **Club-Liga** → Derby, Geschenk-Ökonomie mit Empfangs-Cap, Mitglieder-Statistiken). **Club-Liga definiert:** wöchentliche 20er-Gruppen, Divisionen Bronze→Master mit Auf-/Abstieg; „+2 %/Division" (6.3) referenziert die erreichte Division. Alle Einsätze zählen — ausdrücklich auch ARENA-Liga-Einsätze.

### Tipp-Duell (v1.0)

- Nur Club-intern (ab L8-Gate greift im MVP die Freundesliste, Duelle kommen mit Clubs in v1.0).
- **Bindung:** an das nächste Liga-Spiel **zum Zeitpunkt der Erstellung**; der Herausgeforderte kann bis zum Anstoß annehmen (Push), sonst verfällt die Herausforderung (Erstattung). *Demo-Artefakte simulieren Sofort-Annahme.*
- **Einsatz:** gleich hoch für beide; Cap = **min(Level-Cap beider Spieler)** — der Herausforderer sieht das Limit vorab.
- **Pot & Rake:** Gewinner erhält 95 % des Pots; keiner richtig ⇒ Erstattung. Kein freier P2P-Transfer (Escrow + Settlement-Bindung; Einordnung Kap. 19).
- **Ausbau:** Revanche, Duell-Bilanz in der Mitglieder-Tabelle, Duelle auf Realspiele (späte Auflösung), Tages-Duell-Caps.
- **Collusion-Schutz:** Rake als Transfersteuer, Caps, Duell-Graph-Anomalieerkennung, Geräte-Fingerprints — plus definierter **Review-Prozess mit Personal** (Kap. 15).

### Tipp teilen & Copy-Bet (Phase 3, aus v1 übernommen)

Wettschein in den Club-Chat posten; Mitglieder gehen per Tap mit eigenem Einsatz mit (Rebet-Muster).

---

## 13. Stadion, Minigame & Sammel-Meta

- **Stadion:** 4 Ausbauten × 5 Stufen; **Stufe n = 250.000 × 2^(n−1)**; Vollausbau 31 Mio; Ertrag: XP (Kosten/20), Status, **+1,5 % Arena Bonus je Stufe (max +30 %)**. Ausbau-Ideen: visuelles Stadion, Club-Stadion (Phase 3).
- **Arena Spins:** 3×3, 5 Linien, Paytable 5×–60×; Gewinnbasis 0,5 × Bonus-Basis; nur Freispiele; Fest-XP; Ergebnis vor Animation fix (Server-RNG); Länder-Feature-Flag. Freispiel-Quellen: Bonus (+2/Claim), Rad, Challenges, Level-Ups (+3), Rettungsleine.
- **Free-Bet-Token: in v3 gestrichen** (v1-Mechanik ohne v3-Vergabeweg). Das Kaufverbot in Kap. 17/19 gilt generisch für „Gewinnchancen-Ressourcen jeder Art" — falls Free-Bets je eingeführt werden, sind sie damit abgedeckt.
- **Sammelalbum:** Phase 3 (Drops aus Settlements, Rad, Chests).

---

## 14. FTUE & Onboarding (neu — Grundlage des D1-Gates)

1. **Start ohne Registrierungszwang** (Guest/Sign in with Apple); Progress-Migration bei späterem Login.
2. **18+-Gate:** Store-Rating 18+ + Selbstauskunft im FTUE; ob echte Altersverifikation nötig ist (simuliertes Glücksspiel unter Wettmarke), entscheidet das Gutachten (Phase 0).
3. **Skript Minute 1–5:** Willkommenspaket (1 Mio) → geführter Liga-Tipp auf das nächste Spiel (Anstoß < 30 s) → **erstes Sofort-Settlement in Minute 1–3** (ehrliches D0-Ziel: das *Erlebnis* Settlement, kein garantierter Gewinn — Gewinn-Tuning wäre ein Verstoß gegen Kap. 16) → Bonus-Claim erklärt (+Freispiele → 1 geführter Arena-Spin) → Tages-Tipp setzen → Level 3–4 via FTUE-Fest-XP.
4. **Permission-Momente:** Push-Pre-Permission nach dem ersten Settlement („Wir sagen dir, wenn dein Tipp durch ist"); ATT nur falls nötig, spät. **Push-Opt-in-Rate ist KPI** (Kap. 21) — das Retention-Modell hängt an Push.
5. **Consent-Flow** (Analytics-Klassen, Kap. 21) beim Start, granular.
6. Gesperrte Kern-Features (Live/Cash-out ab L10, C6 ab L20) sind sichtbar geteasert.

---

## 15. Betrieb & Organisation (neu)

- **LiveOps-Kadenz (v3):** täglich Challenges/Bonus/Featured-Liga-Events · wöchentlich Club-Liga/Chest/C6/Wochen-Truhe · 2-wöchentlich Liga-Saison (Ph. 2) + A/B-Event · monatlich Kosmetik/Feature-Drop · 6–8 Wochen große Season (Ph. 3) · ad hoc Sport-Großereignisse. Alles Remote-Config, kein Release-Zwang.
- **Personal & Prozesse (in Phase 0 zu beziffern — Opex ist beim Engagement-Produkt die zentrale Business-Case-Größe):** LiveOps/Economy-Analyst (A/B mit Holdout ist Pflichtprozess), Support (24/7-Liga ⇒ Settlement-Disputes; Replays als Beweismittel), **Moderationsteam ab v1.0** (Chat, Apple 1.2, Leader-Tools), Collusion-/Fraud-Review, CRM-Betrieb, On-Call für Liga-Engine/Feed.
- Community-/Krisenprozesse (RG-Eskalation, Presseanfragen zum Thema simuliertes Glücksspiel).

---

## 16. UX, Game Feel & Barrierefreiheit

- **Orientierung:** Landscape als Arbeitsentscheidung (E4). **Governance:** Vor Entwicklungsstart Usability-Test (n ≥ 12, Portrait- vs. Landscape-Artefakt; vorab definierte Kriterien: Task-Erfolg/-Zeit Wettschein & Liga, Einhand-Nutzung, Second-Screen-Szenario, Präferenz). Bei klarem Portrait-Vorteil entscheidet der Auftraggeber **neu auf Datenbasis** — die Architektur hält die Orientierung als reine Layout-Schicht (zwei Chrome-Varianten; Doppelpflege-Kosten sind im Budget auszuweisen, nicht wegzudefinieren).
- **Reaktionsgefühl:** < 100 ms sichtbare Antwort; gezielte DOM-/View-Patches statt Re-Renders (kein Tap-Verlust); Latenz hinter Animationen (v1-Muster auf Wett-Momente).
- **Haptik & Zelebration:** Claim-Pop, Tor-Impact, Settlement, Duell-Sieg; gestufte Win-Feiern, überspringbar. **Ethik unverändert:** keine LDW, kein Near-Miss-Tuning, keine Fake-Knappheit.
- **Barrierefreiheit (neu, EAA/BFSG seit 28.06.2025 anwendbar — IAP-Shop macht die App plausibel prüfpflichtig):** BFSG-Anwendbarkeitsprüfung in den Gutachtensauftrag (Phase 0); MVP-Akzeptanzkriterien: VoiceOver-Pfade für Kernflüsse, Dynamic Type, Mindestkontraste (Gold-auf-Dunkel prüfen!), Reduced-Motion-Modus, **nicht-zeitkritische Alternativen** (verlängerte Annahmefenster/Assist-Modus für Suspendierung & Annahmeschluss), Haptik nie alleiniger Informationsträger.
- **Lokalisierung:** MVP **DE + EN**; Soft-Launch-Markt bestimmt weitere Sprachen (Kap. 22); saubere Pluralisierung, Kurzform-Zahlen.

---

## 17. Monetarisierung & Engagement-Messung

- IAP-Coin-Packs (5 Punkte, 1,99–49,99 €), dezenter Shop, keine aggressiven Offers/Piggy-Bank/Ads/Abos. **Nie kaufbar:** Gewinnchancen-Ressourcen jeder Art (Freispiele, Free-Bets, Boosts, Duell-Vorteile).
- Erwartung: ARPDAU 0,05–0,15 USD, Konversion 1–2 %.
- **Engagement-Wert messbar machen (Auflage zu E3 — sonst ist der Betriebsmodus nicht steuerbar):**
  1. **Opt-in-Verknüpfung** („Merkur-Konto verknüpfen" für Kosmetik-Bonus, nur mit granularer Einwilligung; erfüllt die Zweckbindung aus Kap. 19) → messbare Kennzahl „verknüpfte Aktive".
  2. **Brand-Lift-/Inkrementalitätsmessung** im DE-Beta-Betrieb (Panel/Umfrage; keine CRM-Datenflüsse nötig).
  3. **Zielwerte & Kill-Kriterien** vor Soft Launch festlegen (z. B. Kosten je aktiv gebundenem Nutzer vs. UA-Benchmark der Wettmarke; Opex-Deckel aus Kap. 15).

---

## 18. Responsible Gaming

v1-Suite komplett (Limits, Reality-Checks, Pausen, Selbstausschluss, Kaufhistorie, Hilfe-Links, Behavioral Monitoring mit Offer-Unterdrückung, ehrliche Mathematik, Fair-Play-Charta) + v3: Limits/Checks gelten ausdrücklich für Liga & Duelle; Liga kommuniziert 92,5 % Auszahlungsquote offen; neutrale Trefferquoten-Darstellung (keine Skill-Illusion); Duell-Herausforderungen ablehnbar ohne Pranger, Duell-Push-Cap.

---

## 19. Regulatorik & Store-Compliance

| Bereich | v3-Status |
|---|---|
| **Gate G0** | Merkur-Annahme formal bestätigen — Vorbedingung für Gutachtensauftrag, Feed-Workshop, Naming. **Plan B** (Nicht-Merkur): externer Feed (Sportradar/Genius, F2P-Klausel) + separate Marke; reaktiviert v1-Risiken #1/#5 |
| DE / § 5 GlüStV | Unter Merkur-Annahme voraussichtlich entschärft (GGL-Lizenzen auch für virtuelle Automatenspiele) — **Gutachten v3**: Arena Spins (freispiel-only) werberechtlich, **ARENA Liga** (virtuelles Wett-Derivat ohne Geldwert), Tipp-Duell (Escrow-Mechanik vs. P2P), Dachmarke/Naming, Altersverifikationspflicht (Kap. 14), **BFSG** (Kap. 16) |
| Apple | 5.3.3 / 3.1.1 / Rating 18+ als Konstante / R18+ AUS / UGC 1.2 / Pre-Submission mit v3-Featureset |
| USA „thing of value" | trifft Coin-Wetten im Kern → Geo-Liste = Marktentscheidung; Rettungsleine + 24/7-Liga als Verteidigung |
| Soft-Launch-Märkte | **Regulatorik der Kandidaten prüfen (Phase 0):** Ontario/AGCO-Umfeld, Norwegen (Monopol/Werberecht), Schweden — bisher ungeprüft (Review-Lücke) |
| Datenschutz | F2P-Wettdaten = RMG-CRM-relevant ⇒ strikte Zweckbindung; Verknüpfung nur per Opt-in (Kap. 17); Data-Flow-Diagramm als Gutachten-Anlage |
| Geo/Flags | Belgien blocken; Länder-Featureset-Flags ab MVP (Arena Spins!) |

---

## 20. Technische Architektur

### 20.1 Client
SwiftUI-first + SpriteKit-Modul (Minigame/Rad); Core Haptics; kein Unity; Android Kotlin (+ optional KMP für Domain-Logik); Orientierung als Layout-Schicht (zwei Chromes). Referenzstruktur: `arena-ios/` (GameState-Schicht = spätere Server-Schnittstellen).

### 20.2 Backend-Services
Wie v3-Erstfassung (12 Services): Cashpoint-Ingestion (Mandanten-Trennung) · Katalog/Kuratierung · Odds-Cache + WS-Fanout · Bet-Service (Repricing, Idempotenz, Level-Cap) · Settlement-Engine (leg-weise, Void-Regeln, Massen-Settlement gebatcht) · Cash-out-Pricing · **Virtual-League-Engine** (Preis = Simulationsmodell, Kalibrier-CI aus 6.6, auditierbarer RNG, Replays) · Duell-Service (Escrow, Annahme-Timeout, Collusion-Detektion) · Bonus/Engagement (atomar, Pending-Rad, Serien, Challenges mit Zeitzonen-Reset) · Wallet/Ledger (append-only; Coins + Freispiele getrennt) · Club/Chat (Nakama-Sidecar-Option) + Moderation · IAP/RG/Analytics/CRM.

### 20.3 Datenmodell-Kern
v3-Erstfassung + **Friend** (Phase 1) · Duel(+Escrow) · VMatch(Seed/Modellversion) · VTable/VSeason (Ph. 2) · C6Ticket · StadiumState · Streaks (BonusSerie/TippSerie/Wochenbogen getrennt).

### 20.4 Sicherheit
v1-Paket + Stale-Odds-/Late-Betting-Schutz (Repricing, Annahmeschluss), Duell-Collusion, Liga-Volumen-Caps, Multi-Account-Farming.

---

## 21. Analytics & KPIs

**North-Star (präzise):** Ø je DAU: Anzahl **settled Coin-Einsatz-Wetten** (Realsport + Liga) **+ angenommene Duelle**. Ausgeschlossen: Gratis-Tages-Tipp, Freispiel-Spins, Claims (Faucet-Aktionen — eigene Gesundheitsmetriken).

| Kategorie | KPI | Ziel (Jahr 1) |
|---|---|---|
| Retention | D1/D7/D30 je Install-Kohorte (Spieltag/Nicht-Spieltag) | ≥ 30/28 · 14/12 · 8/7 % — *D7-Gate im Soft Launch bewusst ohne Clubs kalibriert; Interpretationsregel: liegt D7 bei 10–12 %, gilt das Gate als „bestanden mit Auflage v1.0-Clubs", darunter Kern nachtunen* |
| Engagement | Sessions/Tag · Ø Länge · % DAU mit ≥ 1 Liga-Tipp | 3–5 · 8–12 Min · ≥ 50 % |
| FTUE | Abschlussrate FTUE · **Push-Opt-in** · D0-Settlement-Quote | ≥ 75 % · ≥ 55 % · ≥ 80 % |
| Sport | % DAU mit Realsport-Wette (Spieltage) · C6/WAU | ≥ 45 % · ≥ 40 % |
| Bonus | Claim-Rate · Bonus-Serien-Halterate D7 | ≥ 45 % · Monitoring |
| Social (v1.0) | % DAU in Clubs · Duelle/Club-DAU/Woche | ≥ 40 % · ≥ 1,5 |
| Ökonomie | Faucet/Sink je Segment · **Liga-Hold effektiv (Soll 7,5 %)** · Balance-Median in „Tagen Spielkapazität" | Dashboard + Alerts ab Tag 1 |
| Engagement-Wert | verknüpfte Aktive (Opt-in) · Brand-Lift (DE-Beta) | Zielwerte in Phase 0 (Kap. 17) |
| Monetarisierung | Konversion · ARPDAU | 1–2 % · 0,05–0,15 USD |

Event-Taxonomie als PRD-Pflichtteil (Events + Properties + Consent-Klasse je Story).

---

## 22. Roadmap & MVP

### Gate G0 (sofort, vor allen Ausgaben)
Auftraggeber-/Merkur-Annahme formal bestätigen. Bei Nicht-Bestätigung: Plan B aktivieren (Kap. 19) und Kap. 10/18/19 revidieren.

### Phase 0 — Fundament (4–6 Wochen)
Rechtsgutachten v3 (inkl. Liga-/Duell-Einordnung, Altersverifikation, BFSG, Soft-Launch-Märkte) · Cashpoint-Workshop (Mandanten-Trennung, SLA, Marktabdeckung je Zielmarkt) · **Ökonomie-Simulation als hartes Gate** (Monte-Carlo; liefert Launch-Faucets/Sinks; Demo-Werte sind ausdrücklich nicht launchfähig — Kap. 6.2) · Orientierungs-Usability-Test mit Entscheidungsregel (Kap. 16) · Naming · Team-/**Opex-Plan** (Kap. 15) · Soft-Launch-Marktwahl (Lokalisierung/Content-Fit/Regulatorik — Kandidaten-Matrix statt Vorfestlegung auf Kanada/Skandinavien).

### Phase 1 — MVP / Soft Launch (Ziel 6–7 Monate, 9–12 FTE — mit Descope-Leiter)
**P0 (unverzichtbar):** Liga komplett (inkl. Kalibrier-CI) · Sportsbook Pre-Match · Bonus-System · Wallet/Ledger · Einsatz-Slider/Level · FTUE (Kap. 14) · RG-Suite · Analytics/Remote-Config · Geo-Flags.
**P1 (Soll):** Live + Cash-out Realsport · Tages-Tipp · Challenges · Arena Spins · Stadion · Freundesliste/Geschenke · IAP-Shop.
**P2 (erste Streichkandidaten bei Terminrisiko):** C6 → v1.0 · Kosmetik · zweite Sprache über DE/EN hinaus.
*Descope-Regel: Gestrichen wird von unten (P2→P1); P0 ist der Produktkern. Live/Cash-out ist Kern-USP, aber der einzige große P1-Posten mit eigenem Backend-Pfad — fällt er aus dem MVP, verschiebt sich das L10-Gate auf v1.0 und der Soft Launch testet den Evergreen-Kern.*
**Soft-Launch-Gates:** D1 ≥ 28 % · D7 ≥ 12 % (Interpretationsregel Kap. 21) · Liga-Teilnahme ≥ 45 % · Claim-Rate ≥ 40 % · Faucet/Sink im Simulationszielband. Launch-Timing an Sportkalender koppeln.

### Phase 2 — v1.0 (+3–4 Monate)
Clubs komplett + **Tipp-Duelle** · C6 · Liga-Saisons + Liga-Cash-out · Liga-Blitz-Turniere · Duelle auf Realspiele · Statistik-/Leaderboard-Ausbau (wöchentliche Resets, Stat-Cards, Hall of Fame — aus v1 Kap. 12) · Moderationsteam-Betrieb · zurückhaltende Offers.

### Phase 3 — LiveOps-Reife
Derby · große Seasons + Album · Copy-Bet/Tipp-teilen · Kosmetik-Shop · Club-Stadion · Mega-Season · **Android (Kotlin) — Timing-Abwägung: für das Engagement-Ziel in DE ist die Android-Lücke (~60 % Marktanteil) strategisch relevant; Vorziehen nach Soft-Launch-Evidenz prüfen** · DTC-Prüfung.

---

## 23. Risiken & offene Entscheidungen

| # | Risiko / Entscheidung | Schwere | Mitigation |
|---|---|---|---|
| 1 | **Merkur-Annahme unbestätigt** — trägt Feed, Regulatorik-Story, Architektur, Naming | **Hoch (Tragweite)** | Gate G0 vor allen Ausgaben; Plan B dokumentiert (Kap. 19) |
| 2 | **Ökonomie-Balancierung** — Demo-Faucets verletzen Zielband um Faktor 4–8 | Hoch | Simulation als Phase-0-Gate; Faucet/Sink-Dashboard + Alerts; nur A/B mit Holdout; Kalibrier-CI |
| 3 | **Rechtsgutachten v3 offen** (Dachmarke, Liga, Duell, Altersverifikation, BFSG, Soft-Launch-Märkte) | Hoch | Phase 0 sofort nach G0; Arena Spins hinter Länder-Flag |
| 4 | **Liga-Taktung als Session-Träger unvalidiert** (Frequenz-Rolle bewusst nicht ersetzt) | Mittel-Hoch | Soft-Launch-Experimente (Parallelität/Markttiefe/Taktung); Session-KPIs nicht allein auf Liga rechnen |
| 5 | **Duell-Collusion** | Mittel-Hoch | Rake, Caps, Graph-Anomalieerkennung, Review-Prozess (Kap. 15) |
| 6 | **Orientierung** (Arbeitsentscheidung vs. Portrait-Konvention) | Mittel | Test + Entscheidungsregel (Kap. 16); Layout-Schicht; Doppelpflege budgetieren |
| 7 | **Engagement-Wert unmessbar** → Produkt nicht steuerbar | Mittel | Kap.-17-Auflagen (Opt-in-Verknüpfung, Brand-Lift, Kill-Kriterien) vor Soft Launch |
| 8 | **MVP-Terminrisiko** (Scope) | Mittel | Descope-Leiter (Kap. 22); Budget-/Opex-Plan Phase 0 |
| 9 | **Moderations-/Betriebsaufwand** (24/7-Liga, Chat, Duelle) — v1-Risiko reaktiviert | Mittel | Kap. 15; Moderationsteam ab v1.0; Opex im Business Case |
| 10 | Liga-Wahrnehmung („RNG in Sport-Optik") · Gateway-Kritik | Mittel | Transparenz-Features; Engagement-Modus offensiv; Fair-Play-Charta |
| 11 | Soft-Launch-Markt-Fit (Lokalisierung/Content/Regulatorik) | Mittel | Kandidaten-Matrix Phase 0 statt Vorfestlegung |
| 12 | Apple-Review (18+, 5.3, UGC) | Mittel | Pre-Submission; keine Grauzonen |

**Entschieden:** E1–E3, E5–E9 · E4 als Arbeitsentscheidung mit Test-Gate. **Offen:** G0 · Gutachten-Folgen (Marke, DE-Featureset, Altersverifikation) · Orientierung final · Soft-Launch-Markt · Liga-Parallelität/Taktung · Launch-Balancing (Simulation).

---

*Anhänge A–C: Research-Stand Juli 2026 (v1-spezifische Schlussfolgerungen ersetzt durch dieses Dokument). Review-Protokoll: 4 Perspektiven (Zahlen/Formeln · Vollständigkeit vs. v1 · interne Konsistenz · Advocatus Diaboli), adversarial verifiziert am 12.07.2026; alle bestätigten Findings sind eingearbeitet oder als Risiko/offene Entscheidung geführt.*
