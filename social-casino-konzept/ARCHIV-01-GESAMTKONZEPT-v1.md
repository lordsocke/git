# Gesamtkonzept: „ARENA" — Social-Casino- & Social-Sportsbook-App (Virtual Currency)

**Arbeitstitel:** ARENA (Platzhalter, Naming siehe Kap. 14 — aus markenrechtlichen Gründen ggf. bewusst getrennt von der Sportwetten-Dachmarke)
**Auftraggeber:** Internationaler Sportwetten-Anbieter (Top-Tier)
**Plattform:** iOS (nativ), App Store, 18+
**Währungsmodell:** Eine einzige Währung — **Coins** (keine Premium-Währung, kein Cash-out, kein Handel)
**Vorbild:** Slotomania (Playtika), erweitert um Free-to-play-Sportwetten und ein Club-System nach Clash-of-Clans-Vorbild
**Stand:** Juli 2026 · Basis: Research-Anhänge A–C (Slotomania-Deepdive, Wettbewerbslandschaft, Technik & Regulatorik)

---

## Inhaltsverzeichnis

1. [Executive Summary](#1-executive-summary)
2. [Markt & Positionierung](#2-markt--positionierung)
3. [Produktvision & Spielsäulen](#3-produktvision--spielsäulen)
4. [Zielgruppen & Spielertypen](#4-zielgruppen--spielertypen)
5. [Core Loops](#5-core-loops)
6. [Coin-Ökonomie (Ein-Währungs-Modell)](#6-coin-ökonomie-ein-währungs-modell)
7. [Leveling & Progression](#7-leveling--progression)
8. [Das Bonus-System (inkl. 3-Stunden-Bonus & Special Bonus)](#8-das-bonus-system)
9. [Clubs — das soziale Rückgrat](#9-clubs--das-soziale-rückgrat)
10. [Virtuelles Sportsbook & Live-Wetten](#10-virtuelles-sportsbook--live-wetten)
11. [Challenges, Events, Seasons & LiveOps](#11-challenges-events-seasons--liveops)
12. [Statistiken, Leaderboards & Profile](#12-statistiken-leaderboards--profile)
13. [Retention-Architektur: der Tag / die Woche / die Season eines Spielers](#13-retention-architektur)
14. [UX, Animationen & Game Feel](#14-ux-animationen--game-feel)
15. [Monetarisierung](#15-monetarisierung)
16. [Responsible Gaming & Ethik](#16-responsible-gaming--ethik)
17. [Regulatorik & Store-Compliance](#17-regulatorik--store-compliance)
18. [Technische Architektur](#18-technische-architektur)
19. [Analytics & KPIs](#19-analytics--kpis)
20. [Roadmap & MVP-Schnitt](#20-roadmap--mvp-schnitt)
21. [Risiken & offene Entscheidungen](#21-risiken--offene-entscheidungen)

---

## 1. Executive Summary

ARENA kombiniert drei bewährte, bisher nie gemeinsam umgesetzte Bausteine in einer einzigen Coin-Ökonomie:

1. **Social-Casino-Slots** nach Slotomania-Vorbild (Kern-Loop, Level-Progression, Bonus-Kadenz),
2. **ein virtuelles Sportsbook** mit Pre-Match- und Live-Wetten auf echte Sportereignisse (nach Fliff/Rebet-Vorbild) — das natürliche Heimspiel des Auftraggebers,
3. **Clubs** als soziales Netzwerk im Spiel (nach Clash-of-Clans-/Huuuge-Vorbild) mit Chat, gemeinsamen Zielen, Ligen und Club-vs-Club-Events.

Die Wettbewerbsanalyse (Anhang B) bestätigt: **Dieser Dreiklang ist ein unbesetzter Whitespace.** Social Casinos (Slotomania, Huuuge, Cash Frenzy) haben keinen Sportbezug; Social Sportsbooks (Fliff, Rebet) haben kein Casino-Metagame und keine Clubs. Ein Sportwetten-Anbieter bringt genau die Assets mit, die den Unterschied machen: Odds-Feeds, Sport-Know-how, Markenvertrauen und eine sportaffine Zielgruppe.

**Warum der Sport-Teil strategisch entscheidend ist:** Slots erzeugen Sessions, aber Sport erzeugt *Termine*. Ein Bundesliga-Samstag, ein Champions-League-Abend, ein NFL-Sonntag sind externe Appointment-Mechaniken, die kein Spiel-Designer bauen muss — sie existieren bereits im Leben der Zielgruppe. Die App verbindet den „immer verfügbaren" Slot-Loop mit dem „terminierten" Sport-Loop und deckt so beide Retention-Achsen ab.

**Kernentscheidungen dieses Konzepts:**

| Thema | Entscheidung | Begründung |
|---|---|---|
| Währung | Nur Coins (Kundenvorgabe) | Machbar; zweite Progressionsachse läuft über XP/Status/Sammelobjekte statt Premium-Währung (Kap. 6) |
| Leveling | XP = Einsatz + gedeckelter Gewinnanteil (Kundenvorgabe „Mischung aus eingesetztem und gewonnenem Geld") | Formel & Exploit-Schutz in Kap. 7 |
| Bonus | 3-Stunden-Bonus, jeder 3. Claim = Special Bonus, skaliert mit Level (Kundenidee, ausgebaut) | Vollständiges Design in Kap. 8 |
| Plattform | Nativ iOS: SwiftUI-Shell + SpriteKit/Metal-Slot-Renderer | Kundenpräferenz; beste „Game Feel"-Antwort (Kap. 18). Wichtigste Gegenposition: Unity, falls Android zeitnah folgt — Entscheidung muss **vor** Entwicklungsstart fallen |
| Latenz/„Hakeligkeit" | Server-autoritativer RNG, aber Latenz vollständig hinter Animationen versteckt (Optimistic UI, Pre-Fetch, WebSockets) | Client-Autorität wäre bei einer Casino-Ökonomie ein Cheating-Desaster; das flüssige Gefühl erreicht man architektonisch anders (Kap. 18.2) |
| Marke | Separates Branding prüfen | § 5 GlüStV-Dachmarkenrisiko in DE, Gateway-Kritik (Kap. 17) |

**Größte Risiken (Kap. 21):** (1) das deutsche Werberecht (Dachmarke), (2) die Balance der Ein-Währungs-Ökonomie (Playtikas 2025er-Einbruch von −46,7 % YoY nach einem Ökonomie-Rebalancing ist das Warnbeispiel), (3) Reputations-/Gateway-Kritik, weil der Betreiber ein Echtgeld-Anbieter ist.

---

## 2. Markt & Positionierung

### 2.1 Markt

- Social Casino global: ~8,5 Mrd. USD (2024), ~9 % CAGR → ~14,3 Mrd. USD bis 2030.
- Genre-Ökonomie: ARPDAU 0,4–1,0 USD (Spitze SciPlay ~0,94 USD 2024), Payer-Konversion 2–6 %, stark Whale-getrieben.
- Casino-/Card-Genres haben die **beste Mittel- und Langfrist-Retention** aller Mobile-Genres (Habitual Play).
- Social Sportsbooks (Fliff, Rebet) wachsen schnell, sind aber (a) US-zentriert, (b) meist Sweepstakes-basiert (rechtlich riskant, 2025er-Verbotswelle in mehreren US-Staaten) und (c) ohne Casino-/Club-Metagame.

### 2.2 Positionierung

> **„Die Arena für Sportfans: Zocken, Tippen, Teamgeist — ohne echtes Geld zu riskieren."**

- **Gegen Slotomania:** Wir haben Sport — echte Spiele, echte Quoten, echte Samstage. Und ein echtes Club-System statt rudimentärer Clans.
- **Gegen Fliff/Rebet:** Wir haben ein vollwertiges Casino-Metagame (Slots, Level, Sammelalbum, Events) und Clubs — also Beschäftigung *zwischen* den Spieltagen.
- **Gegen alle:** Eine ehrliche Ein-Währungs-Ökonomie ohne Premium-Currency-Verwirrung — ein Verkaufsargument in Store-Reviews und Presse.

### 2.3 Was wir bewusst NICHT bauen

- **Kein Sweepstakes-/Redemption-Modell** (US-Verbotswelle 2025; Anhang C).
- **Kein Cash-out, kein P2P-Handel** mit Marktwert (UK-Lizenzpflicht, „thing of value"-Risiko).
- **Keine Energie-Drossel** à la Coin Master für den Slot-Core (passt nicht zur Session-Philosophie eines Casino-Produkts; Throttling übernimmt die Coin-Balance selbst).
- **Keine Echtgeld-Brücke in der App** (Apple 5.3.3, § 5 GlüStV, Gateway-Kritik).

---

## 3. Produktvision & Spielsäulen

Die App hat **vier Säulen**, erreichbar über eine Tab-Bar (+ zentraler Lobby-Hub):

```
┌──────────────────────────────────────────────────────────────┐
│                        LOBBY (Home)                          │
│   Bonus-Hub · Featured Slot · Nächste Spiele · Club-Feed     │
├──────────────┬──────────────┬──────────────┬─────────────────┤
│    SLOTS     │    SPORT     │     CLUB     │   ICH (Profil)  │
│  Maschinen-  │  Pre-Match   │  Chat, Ziele │  Level, Stats,  │
│  Galerie,    │  & Live,     │  Liga, Derby │  Album, Erfolge │
│  Turniere    │  Tippspiele  │  Geschenke   │  Einstellungen  │
└──────────────┴──────────────┴──────────────┴─────────────────┘
```

1. **Slots** — 6–8 Maschinen zum Launch (monatlich +1–2), gestaffelt nach Level; klassische Video-Slot-Features (Freispiele, Sticky Wilds, Multiplikatoren, Bonus-Minigames) plus 1–2 Signature-Maschinen mit Sport-Thema („Stadium Spins", „Champions Reels"), die es nur hier gibt.
2. **Sport** — virtuelles Sportsbook mit echten Quoten (Feed des Betreibers), Einzel- & Kombiwetten, Live-Wetten, tägliche Pick-Challenges und ein wöchentliches „Super-6"-artiges Tippspiel als Gratis-Jackpot-Event.
3. **Club** — bis 50 Mitglieder, Chat, gemeinsame Wochenziele, Club-Liga mit Auf-/Abstieg, Club-vs-Club-„Derby", Geschenk-Ökonomie, Mitglieder-Statistiken.
4. **Profil/Meta** — Level & XP, Statistiken, Sammelalbum, Erfolge/Badges, Season-Fortschritt, Responsible-Gaming-Einstellungen.

Die Lobby ist der Rhythmusgeber: Sie zeigt immer **den nächsten erreichbaren Vorteil** (Bonus in 42 Min · Club-Chest 78 % · Anstoß in 2 h · Daily Challenge 2/3) — der Spieler soll die App nie öffnen, ohne dass „gerade etwas geht".

---

## 4. Zielgruppen & Spielertypen

### 4.1 Zielgruppen

| Persona | Beschreibung | Primär-Hook |
|---|---|---|
| **Der Sportfan** (Kernzielgruppe des Betreibers) | 21–45, männlich dominiert, verfolgt 1–2 Ligen intensiv, hat die Wett-App vielleicht schon | Live-Tippen ohne Risiko, Tippspiel gegen Freunde/Club, Spieltags-Events |
| **Der Casual-Slot-Spieler** | 30–65, gemischt, spielt Slotomania/Coin Master-artige Apps in Wartezeiten | Slot-Loop, Bonus-Kadenz, Sammelalbum, Level-Fortschritt |
| **Der Soziale** | Spielt wegen Menschen, nicht wegen Mechanik; Discord-/WhatsApp-Gruppen-Typ | Club-Chat, gemeinsame Ziele, Geschenke, Derby |
| **Der Wettbewerbsspieler** | Leaderboard-getrieben, will messbar besser sein | Turniere, Ligen, Tipp-Statistiken (Trefferquote!), Badges |

### 4.2 Spielertypen-Segmentierung (LiveOps)

Ab Tag 1 werden Spieler nach Verhaltensachsen segmentiert (Anhang B, 4.5): **Spending** (Non-Payer/Minnow/Dolphin/Whale), **Engagement** (Daily/Weekend/Lapsed/Churned), **Affinität** (Slot-lastig / Sport-lastig / Social-lastig / Collector). Events, Offers und Push-Inhalte werden je Segment ausgespielt — z. B. bekommt ein Sport-lastiger Spieler am Freitag „Dein Tippschein für den Spieltag wartet", ein Collector „Nur noch 2 Karten bis Set-Abschluss".

---

## 5. Core Loops

### 5.1 Minuten-Loop (Slots)

```
Coins einsetzen → Spin (Server entscheidet, Client zelebriert)
→ Gewinn/Verlust + XP + Club-Punkte + Album-Drop-Chance
→ Balance-Gefühl: „noch ein Spin"
```

Jeder Spin zahlt auf **vier Systeme gleichzeitig** ein: Kontostand, XP/Level, Club-Wochenziel, Sammelalbum. Das ist das wichtigste strukturelle Learning aus Huuuge/Coin Master: *Der Spieler soll nie nur für Coins spielen.* Selbst eine Verlust-Session erzeugt sichtbaren Fortschritt (Level-Balken, Club-Beitrag, Karten) — das entschärft Frust und trägt die Retention durch Downswings.

### 5.2 Stunden-Loop (Bonus & Sport)

```
3h-Bonus abholen → kurze Slot-/Wett-Session → Live-Spiel checken
→ Wette settlen sehen → Challenge-Fortschritt → App schließen
→ Push: „Bonus bereit" / „Anstoß in 30 Min" → Wiederkehr
```

### 5.3 Tages-Loop

Daily Challenges (3 Slot- + 3 Sport-Aufgaben), Daily-Streak-Kalender, Club-Check-in (Chat, Geschenke), Tagesziel der Club-Chest.

### 5.4 Wochen-Loop

Club-Liga-Wertung (Mo–So), Wochen-Tippspiel (Deadline Samstag), Wochen-Chest (7-Tage-Streak), Turnier-Zyklen, Leaderboard-Reset.

### 5.5 Season-Loop (6–8 Wochen)

Season-Pass-artige Belohnungsleiste (nur mit Coins/Spielaktivität, kein Kauf-Pass — Ein-Währungs-Prinzip), saisonales Sammelalbum, Club-Season-Wertung mit Abschluss-Zeremonie, thematisch an den Sportkalender gekoppelt (Bundesliga-Rückrunde, Champions-League-K.o., WM/EM als Mega-Seasons).

---

## 6. Coin-Ökonomie (Ein-Währungs-Modell)

### 6.1 Grundsätze

1. **Coins haben keinen Realwert.** Kein Cash-out, kein Handel, keine Prämien mit Marktwert (rechtliche Grundlage der gesamten App, Kap. 17).
2. **Spielen ist immer möglich.** Die Gratis-Coin-Pipeline garantiert, dass ein Spieler mit Balance 0 innerhalb von max. 3 h wieder auf Mindesteinsatz-Niveau ist — plus sofortige „Rettungsleine" (6.4). Das ist zugleich die wichtigste rechtliche Verteidigungslinie (Big-Fish-Urteil: Problem war „pay to continue").
3. **Eine Währung, viele Fortschrittsachsen.** Was bei anderen die Premium-Währung leistet (Exklusivität, zweite Knappheit), leisten hier **nicht kaufbare** Statusachsen: XP/Level, Club-Punkte, Album-Karten, Badges, Liga-Ränge. Diese sind bewusst *nicht* gegen Coins tauschbar — sonst kollabieren sie in die eine Währung zurück.

### 6.2 Quellen (Faucets) und Senken (Sinks)

| Quellen | Senken |
|---|---|
| Willkommenspaket (einmalig, groß — Benchmark Slotomania: 1 Mio.) | Slot-Einsätze (Haupt-Sink, RTP < 100 %) |
| 3h-Bonus + Special Bonus (Kap. 8) | Sport-Einsätze (Overround wie beim echten Buchmacher, ~92–95 % Auszahlungsquote) |
| Daily-Streak-Kalender | Turnier-Buy-ins (höhere Klassen) |
| Level-up-Boni | Club-Gründung (einmalig) & optionale Club-Kosmetik |
| Daily Challenges & Wochenziele | Kosmetik: Profilrahmen, Kartenhüllen, Jubel-Animationen, Club-Wappen |
| Club-Chest, Liga-Preise, Derby-Preise | „Reroll" einer Daily Challenge |
| Album-Set-Abschlüsse | Streak-Repair (verpassten Streak-Tag heilen) |
| Geschenke von Clubmitgliedern | — |
| Gewonnene Wetten & Slot-Gewinne (Rückfluss) | — |
| Coin-Käufe (IAP) | — |

**Design-Regel:** Netto (Faucets − Sinks) muss für den engagierten Non-Payer leicht negativ sein — genug, um täglich auf komfortablem Einsatzniveau zu spielen, aber nicht genug, um dauerhaft auf dem Maximaleinsatz seines Levels zu bleiben. Der Abstand zwischen „komfortabel" und „maximal" ist der Monetarisierungsraum. **Wichtig (Playtika-Lehre 2025):** Diese Schraube nach Launch nur in kleinen, getesteten Schritten drehen — ein hartes nachträgliches Rebalancing hat Slotomania fast die Hälfte des Umsatzes gekostet.

### 6.3 Inflationskontrolle

Ein-Währungs-Systeme neigen zu Hyperinflation der Zahlen (Slotomania zahlt inzwischen Millionen als Kleinstbonus). Gegenmaßnahmen:

- **Einsatz-Progression als impliziter Sink:** Höhere Level schalten höhere Einsätze frei; die Bonus-Skalierung wächst *langsamer* als der freigeschaltete Maximaleinsatz (z. B. Bonus × 1,12 pro Levelband, Max-Bet × 1,25) — Reichtum bleibt relativ.
- **Kosmetik-Senken** mit reinen Prestige-Preisen für reiche Non-Payer.
- **Turnier-Klassen nach Balance/Level** (Bronze/Silber/Gold-Buy-ins), damit große Balances einen sinnvollen Verwendungszweck haben.
- **Zahlendarstellung** von Anfang an mit Kurzform (1,2 Mio · 3,4 Mrd) und ohne UI-Layout, das an Ziffernbreite hängt.

### 6.4 Sicherheitsnetz („Rettungsleine")

Fällt die Balance unter den Mindesteinsatz des niedrigsten Slots, erscheint einmalig pro X Stunden ein „Comeback-Bonus" (kleiner Coin-Betrag + 10 Gratis-Spins auf einer Starter-Maschine). Zweck: (a) rechtliche Absicherung („weiterspielen nie kaufpflichtig"), (b) Frust-Churn-Prävention, (c) bewusst klein genug, um Kaufanreiz nicht zu zerstören.

---

## 7. Leveling & Progression

### 7.1 XP-Formel (Kundenvorgabe: Mischung aus Einsatz und Gewinn)

```
XP pro Slot-Spin     = 1,0 × Einsatz + 0,25 × Nettogewinn (gedeckelt bei 5 × Einsatz)
XP pro Sportwette    = 1,2 × Einsatz (bei Settlement) + 0,25 × Nettogewinn (gedeckelt bei 5 × Einsatz)
                       Live-Wetten: Einsatz-Anteil × 1,5 (Anreiz für das Differenzierungs-Feature)
XP aus Challenges    = Festbeträge (levelskaliert), ~10–20 % des Tages-XP eines aktiven Spielers
```

**Warum gedeckelter Gewinnanteil:** Reines Einsatz-XP (Slotomania) belohnt stumpfes Durchklicken; reines Gewinn-XP wäre Varianz-Lotterie und bei Sportwetten manipulierbar (Quoten nahe 1,01 spammen). Die Mischung honoriert *Erfolg spürbar* („mein Big Win hat mich fast ein Level gebracht!"), ohne dass ein einzelner Jackpot die Progression sprengt (Cap) und ohne dass Verlieren sich wie Stillstand anfühlt (Einsatz-Basis). Der Sport-Multiplikator 1,2 gleicht aus, dass Wetten seltener und langsamer settlen als Spins.

**Exploit-Schutz:** XP nur auf settled Bets (kein Cash-out-Farming); pro Event & Markt gedeckeltes XP-Volumen; Minimalquote (z. B. 1,20) für XP-Anrechnung bei Sportwetten; serverseitige Anomalie-Erkennung (Kap. 18.4).

### 7.2 Levelkurve & Freischaltungen

- **Endlos-Progression** mit sanft exponentieller Kurve (Level n → n+1 kostet ~8–12 % mehr XP); erste 10 Level in der ersten Session erreichbar (Onboarding-Dopamin), Level 50 nach ~2–3 Wochen aktiven Spielens, ab Level 100 Prestige-Territorium.
- Jedes Level: sofortiger **Level-up-Coin-Bonus** (skalierend) + kleine Konfetti-Zeremonie.
- Freischaltungen nach Levelbändern:

| Level | Freischaltung |
|---|---|
| 1 | Starter-Slot, Sport-Tab (Einzelwetten), 3h-Bonus |
| 3 | Daily Challenges |
| 5 | Zweiter Slot, Kombiwetten (2er) |
| 8 | **Club-Beitritt** (bewusst früh — sozialer Lock-in ist der stärkste Retention-Hebel) |
| 10 | Sammelalbum, Live-Wetten |
| 12+ | Alle 3–6 Level: neue Slots, höhere Max-Einsätze, größere Kombis, Turnier-Klassen, Kosmetik-Slots |
| 20 | Club-Gründung, Wochen-Tippspiel „Captain's Six" |
| 30+ | High-Roller-Lounge (eigener Lobby-Bereich), exklusive Maschinen-Varianten |

- **Meilenstein-Level** (25/50/100/…): großes Paket + permanentes Profil-Badge + Club-Broadcast („Max hat Level 50 erreicht!") — Level-Aufstiege sind sozial sichtbar.

### 7.3 Status-Track (nicht kaufbar)

Parallel zum Level ein **Saison-Statusrang** (Bronze → Silber → Gold → Platin → Diamant), gespeist aus *Aktivität* (XP der laufenden Season), nicht aus Käufen. Status hebt Bonus-Multiplikatoren (Kap. 8) und Geschenk-Limits. Saisonaler Soft-Reset (ein Band runter pro Season) hält den Rang bedeutsam. Damit existiert die VIP-Logik von Slotomania — aber aktivitäts- statt ausgabenbasiert, was zum Ein-Währungs-Modell und zur RG-Haltung (Kap. 16) passt. *(Option für später: ein separates, diskretes Ausgaben-basiertes VIP-Care-Programm für Top-Spender außerhalb der Spiel-UI.)*

---

## 8. Das Bonus-System

Das Herzstück der Retention-Mechanik — die Kundenidee (3h-Bonus, jeder 3. Claim ein Special Bonus, levelskalierend, animiert) wird hier zum vollständigen System ausgebaut.

### 8.1 Der 3-Stunden-Bonus („Arena Bonus")

- **Takt:** Alle 3 Stunden abholbar (max. 8 Fenster/Tag, realistisch 3–5 Claims bei aktiven Spielern — deckt sich mit Slotomanias 3–4h-Benchmark).
- **Akkumulation statt Verfall:** Wird der Bonus nicht abgeholt, wächst er weiter bis zur Kappung bei **6 Stunden (= 1,5 Fenster-Wert)**. Learning aus Jackpot Party/DoubleDown: Verfall bestraft und frustriert, Akkumulation belohnt Wiederkehr *und* verzeiht Schlaf/Arbeit. Push-Notification beim Erreichen der Kappung („Dein Bonus ist voll — hol ihn ab!").
- **Höhe:** `Basis(Levelband) × Statusmultiplikator × Streak-Multiplikator`
  - Basis wächst mit dem Levelband (z. B. +12 % pro Band, siehe Inflationsregel 6.3).
  - Status (Kap. 7.3): Bronze ×1,0 → Diamant ×1,6.
  - Tages-Streak (s. u.): bis ×1,5.
- **Claim-Erlebnis:** Kein stummer „+5.000"-Toast, sondern ein 3–4-Sekunden-Moment: Der Bonus-Button (permanent in der Lobby, mit Countdown-Ring) platzt auf, Coins fliegen physikbasiert in den Kontostand, der Zähler tickt hörbar hoch, Haptic-Feedback (`UIImpactFeedbackGenerator`), dezenter Sound. Überspringbar per Tap (Vielspieler-Respekt).

### 8.2 Der Special Bonus (jeder 3. Claim)

- **Mechanik:** Ein sichtbarer **3-Segment-Ring** um den Bonus-Button füllt sich pro Claim. Beim 3. Claim wird kein normaler Bonus ausgeschüttet, sondern das **Bonus-Rad** gestartet — ein Vollbild-Minigame (Glücksrad im Stadion-Design, Konfetti, Spotlights, Crowd-Sound).
- **Rad-Inhalte (levelskalierend):**
  - Coin-Beträge: 3×, 5×, 8×, 12×, 20× des normalen Bonus (gewichtete Wahrscheinlichkeiten; Erwartungswert ≈ 5× normaler Bonus)
  - 1 Album-Kartenpaket
  - 10–25 Gratis-Spins auf der „Maschine der Woche"
  - 1 **Free-Bet-Token** (Sportwette ohne Coin-Einsatz, Gewinn zählt — brückt Slot-Spieler ins Sportsbook!)
  - Jackpot-Segment (klein, selten): 50× Bonus + Club-Broadcast
- **Warum das funktioniert:** Der 3er-Zähler verwandelt drei einzelne Claims in eine *Serie mit Ziel* (Zeigarnik-Effekt: angefangene Ringe will man vollmachen). Der Special Bonus ist zudem der geplante tägliche „Wow-Moment" — ein aktiver Spieler erlebt ihn 1–2× am Tag.
- **Der Zähler verfällt nie** (auch nicht über Nacht) — sonst wird aus Vorfreude Bestrafung.

### 8.3 Tages-Streak & Wochenbogen

- **Streak-Definition:** Mindestens 1 Bonus-Claim pro Kalendertag.
- **Effekt:** Streak-Multiplikator auf den Arena Bonus: Tag 1 ×1,0 → Tag 7+ ×1,5 (Anzeige als Flammen-Icon mit Tageszähler).
- **Wochenbogen (Jackpot-Party-Muster):** Jeder Tag mit Claim gibt 1 **Schlüssel**; 7 Schlüssel öffnen samstags/sonntags die **Wochen-Truhe** (großes Coin-Paket + garantiertes seltenes Kartenpaket + Kosmetik-Chance).
- **Streak-Repair:** Ein verpasster Tag kann binnen 48 h für Coins „geheilt" werden (Sink + Frust-Prävention). Maximal 1 Repair/Woche.

### 8.4 Weitere Bonusquellen (bewusst schlanke Liste)

Slotomania streut ein Dutzend Bonus-Typen — für den Launch gilt: **wenige, dafür klar verstandene Quellen** (Arena Bonus, Special Bonus, Daily Streak, Wochen-Truhe, Challenges, Club). Mehr Bonusarten (Lotto, Store-Bonus, E-Mail-Boni) sind LiveOps-Optionen für spätere Frische, nicht Launch-Umfang. Ein überladenes Bonus-Menü verwässert die Appointment-Wirkung jedes einzelnen.

---

## 9. Clubs — das soziale Rückgrat

Referenzmodelle: Huuuge/Billionaire (Struktur, Liga), Coin Master (Teams, Requests), Cash Frenzy (Koop-Chest), Clash of Clans (Identität, Rollen). Kernprinzip aus Anhang B: **Beitrag entsteht durch normales Spielen** — es gibt keinen separaten „Club-Grind".

### 9.1 Struktur

- **Größe:** max. 50 Mitglieder. Beitritt ab Level 8, Gründung ab Level 20 (+ Coin-Gebühr als Sink).
- **Typen:** Offen / Auf Anfrage / Nur Einladung. Suchfilter: Sprache, Liga-Rang, Aktivitätslevel, „Lieblingsverein" (Sport-Identität!).
- **Rollen:** Leader, 2 Co-Leader, Elder, Member — mit Kick-/Invite-/Broadcast-Rechten (CoC-Modell).
- **Club-Level:** steigt durch Gesamtaktivität; schaltet Member-Cap-Stufen (30→40→50), Wappen-Kosmetik und Derby-Teilnahme frei.
- **Club-Chat:** Textnachrichten, Emotes/Sticker, Systemkarten (Big Wins, Level-Ups, Wett-Erfolge, „X braucht Karte Y"), angepinnte Ansagen. Moderation: Melden, Blockieren, serverseitige Filter (Kap. 18.5).

### 9.2 Drei Ebenen des Club-Wettbewerbs

1. **Club-Chest (Koop, wöchentlich):** Alle Einsätze der Mitglieder füllen eine gemeinsame Truhe mit 6 Meilenstufen (Cash-Frenzy-Muster). Jede Stufe schüttet an **alle** aus — auch an Schwächere (Inklusion). Fortschrittsbalken prominent im Club-Tab und in der Lobby.
2. **Club-Liga (kompetitiv, wöchentlich):** Clubs werden in 20er-Gruppen gematcht; Wertung = Club-Punkte (1 Punkt je X eingesetzte Coins, Slots und Sport zählen). Ligen Bronze → Master mit Auf-/Abstieg (Billionaire-League-Muster). Liga-Rang gibt permanenten **Bonus-Multiplikator** für alle Mitglieder (+2 % pro Liga-Stufe auf den Arena Bonus) — der Club zahlt buchstäblich auf das Bonus-System ein, dadurch verzahnen sich Kap. 8 und 9.
3. **Das Derby (Club vs. Club, alle 2 Wochen):** 1-gegen-1-Match zweier Clubs über ein Wochenende, thematisch an echte Sport-Topspiele gekoppelt („Derby-Wochenende"). Punkte aus Slot-Aktivität + korrekten Sport-Picks. Gated ab Club-Level X (Huuuge-Conquest-Muster: Exklusivität als Statusanreiz). Sieger-Club: großer Preis + Wappen-Rahmen für 2 Wochen.

### 9.3 Geschenk- & Hilfe-Ökonomie

- **Tägliches Geschenk:** Jedes Mitglied kann 1×/Tag ein Coin-Geschenk an den Club senden (kostet den Sender nichts, Empfänger erhalten levelskalierten Betrag — Bingo-Blitz-Gift-Center-Muster: Geben ist gratis, Nehmen ist wertvoll, Freundschaft wird ökonomisch spürbar).
- **Karten-Requests:** „Ich brauche Karte X" → Mitglieder mit Duplikaten können sie mit einem Tap spenden (Coin-Master-Muster). **Wichtig:** Nur Duplikat-Spenden auf Anfrage, kein freier Handel (Regulatorik, Kap. 17).
- **Jubel-Momente:** Big Wins und gewonnene Hochquoten-Wetten erscheinen als Karte im Chat mit „Glückwunsch"-Reaktions-Button (sendet Mini-Coin-Regen zurück an den Gratulanten — positive Feedback-Schleife).

### 9.4 Mitglieder-Statistiken (Kundenwunsch)

Im Club-Tab pro Mitglied sichtbar (Woche/Season): Club-Punkte-Beitrag, Einsätze, größter Gewinn, Tipp-Trefferquote, Derby-Punkte, Aktivitäts-Ampel (heute/diese Woche aktiv). Sortierbare Tabelle → sozialer Druck & Anerkennung; Grundlage für Kick-Entscheidungen inaktiver Mitglieder (CoC-Dynamik). Details Kap. 12.

---

## 10. Virtuelles Sportsbook & Live-Wetten

### 10.1 Angebot

- **Quellen:** Odds- und Ergebnis-Feed des Betreibers (bzw. Sportradar/Betradar-Vertrag auf F2P-Nutzung erweitern — Lizenzpunkt früh klären, Anhang C).
- **Märkte (bewusst kuratiert, nicht der volle Buchmacher-Katalog):** 1X2/Moneyline, Über/Unter, Handicap, Beide treffen, Ergebnis; Top-Ligen Fußball + je nach Markt NBA/NFL/Tennis/eSports. Kuratierung hält die UX spielerisch statt „Trading-Terminal".
- **Wettarten:** Einzel, Kombi (2er ab Level 5, größere mit Level), System später.
- **Live-Wetten (ab Level 10):** Live-Quoten auf laufende Spiele, Cash-out-Funktion (in Coins) als Spannungs-Feature. Live-Einsätze geben 1,5× XP (Kap. 7.1) — Live ist das Feature, das kein Social Casino hat, also wird es progressionsseitig gefördert.
- **Settlement-Erlebnis:** Gewonnene Wetten werden zelebriert (Push „Dein Tipp ist durch! +48.000 Coins" + Animation beim nächsten App-Start); der Wettschein-Verlauf ist ein eigener kleiner Feed.

### 10.2 Tägliche Pick-Challenges (Fliff-Muster)

Täglich 5 kuratierte Aufgaben („Tippe ein Spiel der Premier League", „Platziere einen 2er-Kombi", „Gewinne eine Live-Wette") → je XP + Coins; alle 5 = Tagesbonus. Erzeugt Wett-Routine auch an Tagen ohne „eigenes" Spiel.

### 10.3 „Captain's Six" — das Wochen-Tippspiel (Sky-Bet-Super-6-Muster)

- Kostenlos, 1 Tipp-Set pro Woche: 6 Spielausgänge des Top-Spieltags.
- **6/6 richtig = Community-Jackpot** (riesiger Coin-Betrag, wird bei Nichtgewinn progressiv größer — dauerhafter Gesprächsstoff); Teilpreise ab 4/6.
- **Club-Wertung:** Durchschnittspunkte der Mitglieder fließen als Bonus in die Club-Liga → das Tippspiel wird zum wöchentlichen Club-Ritual („Habt ihr alle getippt?!").
- Deadline-Push am Samstagvormittag = zuverlässiger wöchentlicher Re-Engagement-Anker mit *externem* Grund.

### 10.4 Social Betting

- **Tipp teilen:** Jeden Wettschein in den Club-Chat posten; Mitglieder können mit einem Tap **mitgehen** („Copy-Bet" mit eigenem Einsatz — Rebet-Muster).
- **Tipp-Duell:** Direkte 1-gegen-1-Challenge („Ich sage Bayern, du sagst Dortmund — 50.000 Coins?") mit Escrow durch den Server. *(Hinweis: kein P2P-Coin-Transfer im freien Sinne — beide Einsätze gehen in einen Pot, der Server settlet; rechtlich als Spielmechanik gestaltet, nicht als Überweisung.)*
- **Leaderboards:** Wöchentlich pro Sportart: höchste Trefferquote (min. N Wetten), höchster Multi-Gewinn, Club-interne Tipp-Tabelle.

### 10.5 Abgrenzung zum Echtgeld-Produkt (kritisch)

**In der App gibt es keinerlei Hinweis, Link oder CTA zum Echtgeld-Sportsbook.** Kein „Jetzt echt wetten", keine geteilten Accounts mit Echtgeld-Guthaben, keine Odds-Deep-Links in die Wett-App. Gründe: Apple 5.3.3 (IAP-Währung darf nicht mit RMG verknüpft sein), § 5 GlüStV (Kap. 17), Gateway-/Reputationsrisiko (Kap. 16). Der strategische Wert für den Betreiber entsteht indirekt: Markenbindung, First-Party-Daten (mit Consent), Engagement-Ökosystem — nicht durch In-App-Konversion.

---

## 11. Challenges, Events, Seasons & LiveOps

### 11.1 Daily Challenges

- 3 Slot- + 3 Sport-Aufgaben täglich (levelskaliert generiert), z. B. „300 Spins auf beliebiger Maschine", „Triff 3 Freispiel-Trigger", „Gewinne 2 Wetten mit Quote ≥ 1,5".
- Alle 6 = Tages-Chest. 1 Reroll/Tag gegen Coins (Sink).
- Challenge-Fortschritt läuft passiv beim normalen Spielen mit (kein „Questlog-Gefühl").

### 11.2 Sammelalbum („ARENA-Album", SlotoCards-Muster)

- Pro Season ein Album mit ~15 Sets à 9 Karten (Themen: Stadien, Legenden-Archetypen, Maskottchen — Vorsicht: keine echten Spielernamen ohne Lizenz).
- Karten droppen aus Spins (wahrscheinlichkeitsbasiert, einsatzskaliert), Wetten-Settlements, Special Bonus, Chests.
- Set-Abschluss: eskalierende Coin-Pakete + Kosmetik; Album-Abschluss: Mega-Preis + permanentes Badge.
- Duplikate: an Clubmitglieder auf Anfrage spendbar (9.3) oder im „Recycler" gegen Punkte für ein Bonus-Rad einlösbar.
- **Club-Album-Twist (Slotomania-Clan-Album):** 1 gemeinsames Club-Set pro Season, bei dem jede von *irgendeinem* Mitglied gezogene Club-Karte allen gehört.

### 11.3 Turniere

- **Blitz-Turniere (Tournamania-Muster):** 20–30 Min., automatische Einschreibung beim Spielen einer markierten Maschine, Live-Leaderboard (Punkte = Gewinne relativ zum Einsatz — nicht absolut, sonst gewinnen immer High-Roller), Top-N-Preise.
- **Klassen nach Levelband/Buy-in** (Bronze/Silber/Gold), damit Anfänger reale Gewinnchancen haben und große Balances einen Sink finden.
- **Wochenend-Specials:** thematisch an Sport-Events gekoppelt („Champions-Turnier am CL-Abend").

### 11.4 Seasons (6–8 Wochen)

- **Gratis-Belohnungsleiste** (kein Kauf-Pass): Season-Punkte aus XP, Challenges, Tippspiel, Derby → 40–50 Stufen mit Coins, Kartenpaketen, Kosmetik, Free-Bet-Tokens; 3 große Meilenstein-Momente.
- Saisonthema an Sportkalender gekoppelt; **WM/EM/große Turniere = Mega-Seasons** mit eigenem Album, eigenem Tippspiel-Modus (Bracket!), Sonder-Slot-Skin.
- Season-Ende: Abschluss-Zeremonie (persönliche Statistik-Story im Instagram-Story-Format — teilbar, organische Akquise).

### 11.5 LiveOps-Kadenz (Ziel-Rhythmus nach Launch)

| Rhythmus | Inhalt |
|---|---|
| Täglich | Challenges, Bonus-Zyklen, „Maschine des Tages" (XP-Boost) |
| Wöchentlich | Club-Liga, Club-Chest, Captain's Six, Turnier-Zyklus, Wochen-Truhe |
| 2-wöchentlich | Derby, neues Event-Feature im A/B-Test |
| Monatlich | Neue Slot-Maschine, Kosmetik-Drop |
| 6–8 Wochen | Season-Wechsel, neues Album |
| Ad hoc | Sport-Großereignisse, Flash-Events, Personalisierte Offers |

Alles remote konfigurierbar (Kap. 18.3) — **kein App-Release für Event-Änderungen**.

---

## 12. Statistiken, Leaderboards & Profile

Statistiken sind bei Sportfans kein Beiwerk, sondern Kernmotivation (Fantasy-Sports-Lehre). Drei Ebenen:

1. **Ich:** Level, XP-Verlauf, Lieblingsmaschine, größter Win, Slot-RTP-Verlauf („Glücks-Barometer"), Wett-Trefferquote gesamt/pro Liga/pro Markt, Kombi-Statistik, Streak-Rekorde, Badges. Teilbare „Stat-Cards" (Bild-Export).
2. **Club:** Mitglieder-Tabelle (9.4), Club-Historie (Liga-Verlauf, Derby-Bilanz), Hall of Fame (Rekorde: größter Win aller Zeiten, beste Tipp-Woche …).
3. **Global/Freunde:** Wochen-Leaderboards (Tipp-Trefferquote, Turnierpunkte, Album-Fortschritt) mit Freunde-Filter; bewusst **wöchentlich resettet** — ewige Bestenlisten demotivieren Neueinsteiger.

**Design-Grundsatz:** Öffentliche Vergleiche zeigen *relative* Kennzahlen (Trefferquote, Punkte), nicht absolute Coin-Bestände — schützt vor „Pay-to-Flex"-Optik und hält Leaderboards für Non-Payer gewinnbar.

---

## 13. Retention-Architektur

### 13.1 Der ideale Tag eines Spielers (Ziel: 3–5 Sessions)

```
07:30  Push: „Dein Bonus ist voll" → Claim (Streak +1, Ring 1/3)
       → 5 Min Slots, Daily Challenges starten
12:30  Lunch-Session: Bonus-Claim (2/3), Pick-Challenge des Tages,
       Club-Chat checken, Geschenk senden
17:00  Push: „Anstoß in 60 Min — dein Live-Tipp wartet"
20:15  Abend-Session (Hauptsession): Bonus-Claim → SPECIAL BONUS (Rad!),
       Live-Wetten parallel zum Spiel, Slots in der Halbzeit,
       Club-Chest-Stufe erreicht
22:30  Wett-Settlement-Push: „+120.000 Coins — dein Tipp saß!"
       → kurzer Claim-Besuch, morgen weiter
```

### 13.2 Retention-Hebel nach Zeithorizont

| Horizont | Hebel |
|---|---|
| D0 (FTUE) | Großes Willkommenspaket, erster Big-Win-Moment in Minute 1–2 (getunte Starter-Maschine), Level 1→5 in Session 1, Bonus-System + Sport-Tab im Tutorial verankert (Slotomania-Lehre: Meta-Features ins FTUE) |
| D1–D7 | Tages-Streak & Wochenbogen, Daily Challenges, erste Club-Einladung (Level 8 ≈ Tag 2–3), erstes Captain's Six |
| D7–D30 | Club-Bindung (Liga, Chest, Chat), Album-Sets, Status-Rang, Turnier-Routine |
| D30+ | Season-Zyklen, Derby-Rivalitäten, Sammler-Vervollständigung, Sportkalender (der beste D30+-Hebel: die Rückrunde kommt von allein), soziale Verpflichtung gegenüber dem Club |
| Lapsed | Comeback-Paket (gestaffelt nach Abwesenheit), „Dein Club vermisst dich"-Push (nur mit echtem Club-Kontext), Saisonstart-Reaktivierung („Die neue Saison beginnt — dein Rang wartet") |

### 13.3 Warum das langfristig trägt (die Kundenfrage)

Langfrist-Retention entsteht nicht aus einem Feature, sondern aus **überlappenden Verpflichtungs- und Vorfreude-Schleifen**, die nie gleichzeitig „fertig" sind:

1. **Zeitliche Anker** (3h-Bonus, Streak, Wochen-Truhe) — *Gewohnheit*.
2. **Externe Anker** (Spieltage, Live-Spiele, Saisonkalender) — *Anlass ohne Design-Aufwand*; das Alleinstellungsmerkmal gegenüber jedem reinen Social Casino.
3. **Soziale Verpflichtung** (Club-Chest braucht mich, Derby-Wochenende, Chat-Beziehungen) — *der stärkste Churn-Schutz überhaupt*; Spieler verlassen Spiele, aber ungern Menschen.
4. **Unabgeschlossene Sammlungen** (Album 87 %, Ring 2/3, Season-Stufe 34/40) — *Zeigarnik-Effekt*.
5. **Identität & Status** (Level, Rang, Badges, Tipp-Trefferquote als Stolz-Metrik) — *versunkene Identität, nicht nur versunkene Kosten*.
6. **Frische durch LiveOps** (Kadenz 11.5) — *es gibt immer etwas Neues, ohne dass der Kern sich ändert*.

---

## 14. UX, Animationen & Game Feel

### 14.1 Grundsätze

- **Jede Aktion antwortet in < 100 ms sichtbar** (Animation startet sofort, Netzwerk läuft parallel — Kap. 18.2). Das ist die direkte Antwort auf die „Hakeligkeit"-Kritik des Kunden.
- **120 Hz ProMotion** für Reel-Spins und Win-Sequenzen; adaptive Framerate (60/30 Hz idle) für Batterie.
- **Gestufte Win-Zelebrationen:** Win < 5× Einsatz: knappes Funkeln · 5–15×: „Big Win"-Banner + Münzregen · 15–40×: „Mega Win" Vollbild + Slow-Motion-Zähler · > 40×: „Epic Win" mit Screenshake, Konfetti-Kanonen, Club-Broadcast. Alle Sequenzen per Tap überspringbar (Vielspieler!).
- **Haptik als Signatur:** Reel-Stops einzeln fühlbar (leichte Taps), Win-Tiers mit eskalierenden Haptic-Patterns (Core Haptics), Bonus-Claim mit „Pop". Haptik ist das, was native Apps von Web-Apps unterscheidbar macht — hier zahlt die Native-Entscheidung direkt ein.
- **Sound-Design** mit Mute-Respekt (Stummschalter, Hintergrund-Audio anderer Apps nicht unterbrechen).
- **Dark-First-Design** (Casino-Atmosphäre, OLED), klare Zahlen-Typografie, Kurzformate (1,2 Mio).

### 14.2 Ethische UX-Leitplanken (bewusste Abweichungen vom Genre-Standard)

- **Keine Losses-Disguised-as-Wins:** Ein Spin, der netto verliert, wird nicht als Gewinn zelebriert (Genre-Standard wäre das Gegenteil — wir verzichten bewusst, Kap. 16).
- **Kein künstliches Near-Miss-Tuning:** Reel-Stopps folgen dem ehrlichen RNG-Ergebnis.
- Countdown-/FOMO-Elemente ja, aber ohne Dark Patterns (kein „Nur noch 1 verfügbar!" bei digitalen Gütern, keine Fake-Rabatte).

---

## 15. Monetarisierung

### 15.1 Modell

- **Coin-Packs via Apple IAP** (5–7 Preispunkte, 1,99–99,99 €; Apple-Kommission 15–30 % einpreisen). Keine Abos zum Launch (Option: „Season-Booster"-Abo später prüfen — Vorsicht: darf sich nicht wie Premium-Währung anfühlen).
- **Personalisierte Offers** (Segment-basiert, A/B-getestet): First-Purchase-Angebot, Comeback-Offers, Event-Bundles (Coins + Kartenpaket + Free-Bet-Token).
- **Piggy-Bank-Mechanik („Tresor"):** Prozentsatz der Gewinne füllt einen sichtbaren Tresor, der per Kauf geöffnet wird (Endowment-Effekt; +15–20 % Umsatz-Benchmark). **Empfehlung: ja, aber transparent** — Füllstand und Preis immer sichtbar, keine wachsenden Preisstufen ohne Ankündigung (Slotomania-Community-Backlash als Warnung).
- **Rewarded Ads: nein** (Premium-Markenumfeld des Betreibers; Ad-basierte Bonus-Verdopplung wirkt billig und kannibalisiert IAP).
- **Kein Pay-to-Win gegenüber Menschen:** Käufe beschleunigen Coins/Komfort, aber Leaderboards/Tipp-Wertungen basieren auf relativen Metriken (Kap. 12) — wichtig für die Sport-Glaubwürdigkeit.

### 15.2 Erwartungsrahmen

Benchmarks (Anhang B): ARPDAU 0,4–1,0 USD, Payer-Konversion 2–6 %. Konservativer Business-Case sollte mit ARPDAU 0,25–0,40 im Jahr 1 rechnen (neue Marke, kuratierter Content-Umfang), Upside über Sport-Events und Club-getriebene Retention. **Hinweis:** Falls die strategische Priorität des Auftraggebers Engagement/Markenbindung statt Direktumsatz ist (plausibel für einen Wettanbieter), kann die Offer-Aggressivität deutlich unter Genre-Standard bleiben — das Konzept funktioniert in beiden Betriebsmodi; die Entscheidung beeinflusst Ökonomie-Tuning und sollte vor dem Balancing fallen (Kap. 21).

### 15.3 DTC-Perspektive (später)

Playtika verlagert massiv auf eigene Webshops (Q1 2026: +62,8 % YoY DTC). Für v2 prüfenswert (Web-Shop mit Bonus-Coins), abhängig von Apple-Regeln zum externen Kauf im Zielmarkt.

---

## 16. Responsible Gaming & Ethik

Ein Echtgeld-Wettanbieter, der ein Simulated-Gambling-Spiel launcht, steht unter verschärfter Beobachtung (Presse, Regulierer, Wissenschaft). RG ist hier nicht Compliance-Kür, sondern **Markenschutz**:

- **18+ strikt** (Apple-Rating „häufiges simuliertes Glücksspiel" = 18+; Australien R18+ gesetzlich).
- **RG-Suite ab Launch:** selbst gesetzte Kauf-Limits (Tag/Woche/Monat), Zeitlimit-Erinnerungen („Reality Check" nach X Minuten), Spielpausen (24 h bis 6 Wochen), Self-Exclusion (dauerhaft), vollständige Kaufhistorie in der App, Hilfe-Links (check-dein-spiel.de, BZgA, lokale Äquivalente).
- **Behavioral Monitoring:** Frühwarn-Modelle auf riskante Muster (nächtliche Kaufserien, Loss-Chasing-Signaturen); Reaktion: sanfte Interventionen (Pause-Vorschlag, Offer-Unterdrückung für markierte Accounts — *Offers an Risikospieler auszuspielen ist das Reputations-Worst-Case*).
- **Ehrliche Mathematik:** Slot-RTP im realistischen Bereich (~90–96 %), **nicht** geschönt — überhöhte F2P-Gewinnquoten erzeugen falsche Erwartungen und sind der wissenschaftlich meistkritisierte Gateway-Mechanismus (Anhang C, Kim et al.: ~25 % Migration zu Echtgeld binnen 6 Monaten).
- **Keine Echtgeld-CTAs, kein Funnel-Design** (Kap. 10.5) — die App ist ein eigenständiges Unterhaltungsprodukt.
- **Verzicht auf LDW & Near-Miss-Tuning** (Kap. 14.2) — dokumentierbar, auditierbar, kommunizierbar („Fair-Play-Charta" als Teil des Marketings).

---

## 17. Regulatorik & Store-Compliance (Zusammenfassung; Details Anhang C)

| Bereich | Anforderung/Risiko | Konsequenz |
|---|---|---|
| Apple 5.3.3 | IAP-Währung darf nicht mit Real Money Gaming verknüpft sein | Keine RMG-Brücke, getrennte Accounts/Systeme |
| Apple 3.1.1 | Digitale Güter nur via IAP | Coin-Verkauf ausschließlich IAP (Launch) |
| Apple 4.7/4.7.5 | HTML5-Games eingeschränkt; Altersfilter | Slots nativ im Binary |
| Apple Age Rating (neu 2025) | Häufiges simuliertes Glücksspiel = 18+ | 18+ einplanen (Marketing entsprechend) |
| USA/Washington | Big-Fish-Präzedenz: Coins als „thing of value" | Washington geo-blocken oder Mechanik-Gutachten; „Weiterspielen nie kaufpflichtig" (Kap. 6.4) |
| USA/Sweepstakes | Verbotswelle 2025 | Kein Redemption-Element — ohnehin nicht geplant |
| Belgien | Lootbox-/Glücksspiel-Auslegung | Geo-blocken (Branchenpraxis) |
| Australien | R18+ Pflicht für simuliertes Glücksspiel | Rating-Prozess einplanen |
| Deutschland | Social Casino ohne Auszahlung grundsätzlich legal; ABER § 5 GlüStV: Dachmarken-Werberisiko, wenn der Betreiber keine Lizenz für virtuelle Automatenspiele hat | **Separate Marke ernsthaft prüfen**; alternativ DE-Version ohne Slots (nur F2P-Sport); zwingend Kanzlei + ggf. GGL-Abstimmung **vor** Namens-/Markenentscheidung |
| Österreich/NL/UK | Ohne Cash-out/Handel derzeit kein Glücksspiel | Kein Handel, kein Cash-out (Design-Invariante) |
| Datenschutz | DSGVO/ATT: First-Party-Daten nur mit Consent; kein Datenabfluss Richtung Echtgeld-Profil ohne separate Rechtsgrundlage | Consent-Architektur früh designen |

**Wichtigste Einzelmaßnahme:** Die Marken-/Jurisdiktionsfrage (separate Marke vs. Dachmarke; Länder-Featureset) muss **vor** Projektstart juristisch geklärt werden, weil sie Naming, Store-Setup, Geo-Architektur und Marketing bestimmt.

---

## 18. Technische Architektur

### 18.1 Client: Nativ iOS — Empfehlung mit einer wichtigen Weiche

**Der Kundenpräferenz (nativ statt Web) stimme ich zu** — mit präzisierter Begründung: Der Vorteil von nativ ist *nicht*, dass Entscheidungen ohne Server auskommen (das dürfen sie bei einer Casino-Ökonomie nie, s. 18.2), sondern: 120-Hz-Rendering, Core Haptics, APNs-Zuverlässigkeit, App-Attest-Sicherheit, StoreKit-2-IAP und ein UI, das sich anfühlt wie das OS.

- **Stack:** SwiftUI (App-Shell, Lobby, Sport-Tab, Club, Shop, Profil) + **SpriteKit/Metal** für den Slot-Renderer (`SpriteView`-Einbettung; `SKEmitterNode`-Partikel für Win-Celebrations; Custom-Metal-Shader für Glow/Münzregen). Swift Concurrency durchgängig; The Composable Architecture o. ä. optional — wichtiger ist ein sauberes „ein Screen = ein Feature-Modul".
- **Die Weiche:** Will der Kunde binnen ~18 Monaten Android (bei der Zielgruppengröße wahrscheinlich), ist **Unity für den Slot-Core im nativen SwiftUI-Wrapper** der Branchenstandard und spart die Doppel-Implementierung des aufwendigsten Teils. Diese Entscheidung ist vor Sprint 1 zu treffen — nachträglich ist sie ein Rewrite. **Meine Empfehlung: iOS-first nativ wie vom Kunden gewünscht, aber die Slot-Logik (Mathe-Modelle, Konfigurationsformat) plattformneutral spezifizieren**, sodass ein späterer Android-Client (nativ Kotlin oder Unity) dieselben Server-Definitionen rendert.

### 18.2 Das Latenzproblem — richtig gelöst (Antwort auf die Kern-Kritik des Kunden)

Die Diagnose „Apps fühlen sich hakelig an, weil jede Entscheidung vom Server bestätigt werden muss" ist richtig beobachtet — aber die Lösung ist **nicht Client-Autorität**. Eine client-autoritative Coin-Ökonomie wäre binnen Tagen durch Memory-Editing (GameGuardian), Jailbreak-Hooking und Replay-Manipulation zerstört; gefälschte Big Wins würden Leaderboards, Club-Ligen und das Tippspiel entwerten. **Der Server bleibt die einzige Wahrheit (RGS-Muster) — aber der Spieler merkt es nie:**

1. **Sofortige Animation:** Tap → Reels drehen in < 50 ms los (rein clientseitig), der Spin-Request läuft parallel. Die Server-Antwort (50–300 ms) ist längst da, bevor die Reels nach 1,5–2 s auslaufen; der Client steuert sie auf das Server-Ergebnis zu. *Gefühlte Latenz: null.*
2. **Optimistic UI + Idempotenz:** Einsatz wird sofort lokal abgezogen; jede Transaktion trägt einen Idempotency-Key; bei Timeout wird derselbe Spin sicher erneut angefragt (kein Doppelabzug, kein verlorener Gewinn).
3. **Pre-Fetch & Batching:** Turbo-/Autoplay holt Ergebnisse gebündelt (z. B. 10 Spins/Request, serverseitig committed). Der nächste Einzelspin wird bereits während der Win-Präsentation vorgeladen.
4. **Persistenter WebSocket** statt Request/Response-Zyklen: Balance-Updates, Wett-Settlements, Club-Chat, Live-Quoten, Turnier-Leaderboards als Push — nichts davon blockiert je die UI.
5. **Deterministische Replays:** Server persistiert Seed + Modellversion + Ergebnis je Spin; abgebrochene Bonusrunden werden exakt fortgesetzt, Support-Fälle sind beweisbar.
6. **Offline:** Kein Offline-Gameplay (Ökonomie-Integrität). Bei Verbindungsverlust: eleganter Zustand („Verbindung wird wiederhergestellt…"), Lobby bleibt browsebar.

### 18.3 Backend

- **Kern:** Nakama (Heroic Labs) als Basis *oder* Eigenbau in Go/Elixir — Entscheidung nach Team-Skills des Kunden. Nakama liefert Wallet, Chat, Leaderboards, Turniere und server-autoritative Module (Go/TS) out of the box und verkürzt die Time-to-Market deutlich; ein Anbieter dieser Größe hat aber vermutlich Plattform-Teams, die Eigenbau bevorzugen.
- **Slot-Engine:** eigener Service (Go): Mathe-Modelle als versionierte Konfiguration (Symbole, Reels, Paytable, Feature-Trigger), zertifizierbarer RNG (auch wenn Social keine Zertifizierung *verlangt*, schafft ein auditierbarer RNG Vertrauen und hält die Tür zu Prüfsiegeln offen).
- **Sport-Settlement-Service:** konsumiert den Odds-/Ergebnis-Feed (Betradar/Genius; F2P-Lizenzklausel klären), verwaltet virtuelle Wettscheine, Cash-out-Berechnung, Settlement-Fanout via WebSocket/Push.
- **Daten:** PostgreSQL (Wallet/Ledger als Append-only-Buchungssätze — *nie* nur ein Balance-Feld), Redis (Sessions, Leaderboards, Rate-Limits), Event-Stream (Kafka o. ä.) → DWH.
- **LiveOps:** Remote Config (Firebase o. Eigenbau) für Events, Bonus-Parameter, Feature-Flags; Offer-Engine mit Segment-Targeting; alles ohne App-Release schaltbar.
- **Analytics:** Amplitude (Events, Kohorten, Experiment) + eigenes DWH; Push via APNs (Token-based) über CRM-Orchestrierung (z. B. Braze).

### 18.4 Sicherheit & Anti-Cheat

- Wallet-Mutationen ausschließlich serverseitig; Client sendet nur Intents.
- **App Attest** + DeviceCheck, Jailbreak-Heuristiken, zertifikatsgepinnte TLS-Verbindungen.
- IAP: serverseitige Receipt-Validierung (App Store Server API v2, signierte Transaktionen).
- Anomalie-Erkennung: unmögliche Spin-Frequenzen, statistisch auffällige Gewinnraten, Multi-Account-Muster (Club-Punkte-Farming!), Geräte-Fingerprints für Derby-/Liga-Integrität.
- Rate-Limits pro Endpoint; Chat: serverseitige Filter + Melde-Pipeline + Moderations-Backoffice (App-Store-Pflicht für UGC: Melden, Blockieren, Moderation — Guideline 1.2).

### 18.5 Geo & Compliance-Technik

Serverseitiges Geo-Gating (Storefront-Ausschluss + IP/Region-Check) für die Blockliste (mind. Belgien, Washington-Entscheidung offen); länderspezifische Feature-Flags (z. B. DE-Variante ohne Slots, falls die Markenentscheidung das erfordert — Kap. 17).

---

## 19. Analytics & KPIs

**North-Star-Metrik:** *Tägliche „aktive Einsätze" pro DAU* (Spins + settled Bets) — das Äquivalent zu Coin Masters „Spins per DAU": eine Zahl, auf die Bonus-Ökonomie, Events, Clubs und Sportkalender alle einzahlen.

| Kategorie | KPI | Zielwert (Jahr 1) |
|---|---|---|
| Retention | D1 / D7 / D30 | ≥ 32 % / ≥ 15 % / ≥ 8–10 % |
| Engagement | Sessions/Tag · Session-Länge | 3–5 · Ø 8–12 Min |
| Bonus | Claim-Rate 3h-Bonus (Claims/mögliche Fenster) | ≥ 45 % bei WAU |
| Social | % DAU in Clubs · Club-D30 vs. Nicht-Club-D30 | ≥ 40 % · Faktor ≥ 2 erwartbar |
| Sport | % DAU mit ≥ 1 Wette · Tippspiel-Teilnahme/Woche | ≥ 35 % · ≥ 50 % der WAU |
| Monetarisierung | Payer-Konversion · ARPDAU | 2–4 % · 0,25–0,40 USD (konservativ) |
| Ökonomie-Gesundheit | Faucet/Sink-Ratio je Segment · Median-Balance in „Stunden Spielzeit" | Dashboard ab Tag 1, Alerts bei Drift |
| RG | Limit-Nutzung, Interventions-Rate, Beschwerde-Quote | Monitoring + Reporting |

Experimentier-Kultur ab Launch: Jede Ökonomie-Änderung (Bonushöhen, RTP, Offer-Preise) nur via A/B-Test mit Holdout-Gruppe (Playtika-Playbook — und Playtika-2025-Warnung).

---

## 20. Roadmap & MVP-Schnitt

### Phase 0 — Fundament (parallel zur Konzeptfreigabe, 4–6 Wochen)
Rechtsgutachten (Dachmarke/DE, Geo-Liste, Datenfluss-Consent) · Markenentscheidung · Sportdaten-Lizenzklärung (F2P-Klausel) · Plattform-Weiche (pure native vs. Unity-Slot-Core) · Team-Setup.

### Phase 1 — MVP / Soft Launch (ca. 6–8 Monate Entwicklung; Soft-Launch-Markt: z. B. Kanada/Skandinavien)
- 4 Slots (davon 1 Sport-Signature), Level 1–50 ausbalanciert
- 3h-Bonus + Special-Bonus-Rad + Tages-Streak + Wochen-Truhe (das volle Kap.-8-System — es ist der Retention-Kern und muss ab Tag 1 sitzen)
- Sport: Einzel-/2er-Kombi Pre-Match auf Top-Fußball-Ligen, Daily Pick-Challenges
- Daily Challenges, Basis-Profil & -Statistiken, IAP-Shop (Basis), RG-Suite, Analytics/Remote-Config komplett
- **Noch ohne:** Clubs (nur Freundesliste + Geschenke), Live-Wetten, Album, Turniere, Seasons
- Soft-Launch-Ziel: D1 ≥ 30 %, D7 ≥ 12 %, Bonus-Claim-Rate ≥ 40 % — sonst Kern nachtunen statt Features stapeln

### Phase 2 — v1.0 Global Launch (+3–4 Monate)
Clubs komplett (Chat, Chest, Liga) · Live-Wetten + Cash-out · Captain's Six · Sammelalbum · Blitz-Turniere · 8+ Slots · personalisierte Offers.

### Phase 3 — LiveOps-Reife (+laufend)
Derby (Club vs. Club) · Seasons + Season-Leiste · Status-Ränge · Kosmetik-Shop · Tipp-Duelle & Copy-Bets · Mega-Season zum nächsten Großturnier · DTC-Prüfung · Android-Entscheidung.

---

## 21. Risiken & offene Entscheidungen

| # | Risiko / Entscheidung | Schwere | Mitigation / Owner |
|---|---|---|---|
| 1 | **§ 5 GlüStV / Dachmarke DE** — App unter Sportwetten-Marke könnte als unzulässige Casino-Werbung gelten | Hoch | Rechtsgutachten vor Naming; Option separate Marke oder DE-Featureset ohne Slots. *Entscheidung des Kunden nötig.* |
| 2 | **Ökonomie-Balance im Ein-Währungs-Modell** — zu großzügig = kein Umsatz & Inflation; zu knapp = Churn & Big-Fish-Risiko; hartes Nach-Rebalancing = Playtika-2025-Szenario | Hoch | Ökonomie-Simulation vor Launch, Soft Launch, alle Änderungen via A/B mit Holdout, Faucet/Sink-Dashboard ab Tag 1 |
| 3 | **Gateway-/Reputationskritik** (Echtgeld-Anbieter betreibt Simulated Gambling) | Hoch | Kap.-16-Paket vollständig umsetzen und offensiv kommunizieren (Fair-Play-Charta); keine Echtgeld-Funnels |
| 4 | **Plattform-Weiche** (pure native vs. Unity-Core) falsch gestellt → Android wird Rewrite | Mittel-Hoch | Entscheidung in Phase 0 mit ehrlicher Android-Roadmap; Slot-Definitionen plattformneutral |
| 5 | **Sportdaten-Lizenz** deckt F2P nicht ab | Mittel | Früh mit Betradar/Genius klären; Fallback White-Label (Low6 u. a.) |
| 6 | **Apple-Review-Risiken** (18+-Rating, 5.3-Auslegung, UGC-Moderation) | Mittel | Pre-Submission-Review, Moderations-Backoffice ab MVP, keine Grauzonen-Features |
| 7 | **Club-Toxicity/Moderationsaufwand** | Mittel | Filter + Melde-Pipeline + Moderationsteam ab v1.0; Club-Kick-Tools an Leader delegieren |
| 8 | **Multi-Account-/Farming-Exploits** (Club-Punkte, Duell-Absprachen) | Mittel | Anomalie-Erkennung, Geräte-Fingerprinting, XP-/Punkte-Caps (Kap. 7.1) |
| 9 | **Betriebsmodus unklar:** Umsatzprodukt vs. Engagement-/Markenprodukt — beeinflusst Offer-Aggressivität und Ökonomie-Tuning | Mittel | Explizite Zielsetzung mit dem Kunden vor Balancing-Phase festlegen |
| 10 | **Content-Kadenz** (monatlich neue Slots ist teuer) | Mittel | Slot-Framework mit datengetriebenen Maschinen-Definitionen (neue Maschine = Config + Assets, kein Code) |

---

*Anhänge: A — Slotomania-Deepdive · B — Wettbewerbslandschaft · C — Technik & Regulatorik (separate Dateien in diesem Ordner, mit Quellen-URLs).*
