# arena-server — Produktions-Backend (Fundament)

Server-autoritatives Backend für ARENA. Dieses Paket ist **Phase B**
des Go-Live-Plans und liefert das integritätskritische Fundament:

- **B1 Auth** — Gast-Konten + echtes *Sign in with Apple* (Apple-Identity-Token gegen
  Apples JWKS geprüft), eigene Session-Tokens (JWT/HS256), **Account-Migration Gast → Apple**.
- **B2 Ledger-Wallet** — **kein veränderliches `coins`-Feld**. Der Coin-Stand ist die
  Summe eines **append-only Ledgers**. Idempotente Buchungen (Retry-sicher), Sperre pro
  Konto (kein negativer Saldo unter Nebenläufigkeit), atomare Multi-Buchungen.
- **B3 Bet-Service + Settlement-Engine** — server-autoritative Platzierung (der Client
  sendet nur `matchId/market/pick`, **bepreist wird aus der Server-Quote** — manipulierte
  Client-Quoten sind konstruktionsbedingt wirkungslos), Quoten-Ingest aus dem
  Frankfurt-Feed (`matches` + `outrights`, versioniert), leg-weises Settlement
  (1X2/OU25), Kombis, Void/Erstattung, idempotente Payouts über das Ledger,
  **Recovery-Sweep** (Crash-sicher) + **Auto-Void** verwaister Spiele (48 h nach Kickoff).
- **B5 ARENA-Liga-Engine** — virtuelle Runden als normale `matches`-Zeilen
  (competition `arena-liga`): Platzierung/Kombis/Settlement laufen über exakt dieselbe
  reviewte Maschinerie. Preisableitung = Poisson-Modell des Prototyps (Auszahlungsfaktor
  0,925 ⇒ Hold 7,5 %), **Ergebnis deterministisch aus pro Runde gespeichertem Seed**
  (`league_rounds` — auditierbar, reproduzierbar). Taktung konfigurierbar (~45 s Wetten
  + ~90 s live).
- **B7 Engagement-Service** — XP/Level **aktivitätsbasiert** (Tipp 10 · Claim 12 · Spin 4 ·
  Tages-Tipp 25 · Chest 30 · Stadion 15; Kurve 70·L^0,76), 3h-Bonus mit Tages-Serie,
  jeder 3. Claim dreht das **Rad serverseitig** (exakt die App-Segmente, Coin-EV ≈ 3,05),
  Freispiele mit EV 0,481, Level-up-Bonus, **Daily Challenges + Tages-Chest** (Fortschritt
  aus server-sichtbaren Events), **Tages-Tipp** (1×/Tag auf die Liga-Runde, Auflösung im
  Liga-Settlement, Serien-Belohnung), **Stadion** als Ledger-Sink mit Bonus-Boost
  (+1,5 %/Stufe, Gesamt-Multiplikator ×2,0 gedeckelt) — alles als Ledger-Buchungen.
  **Max-Einsatz ist am Level gecapt und wird serverseitig in der Platzierung
  durchgesetzt** (L1 = 40 → Cap L55 ≈ 150 T).

Damit ist das Wallet server-autoritativ statt (wie im Prototyp) lokal in UserDefaults —
der eigentliche Unterschied zwischen „Prototyp" und „Produkt".

## Architektur

| Baustein | Technik | Warum |
|---|---|---|
| API | Fastify (TypeScript, ESM) | schlank, schnell, typisiert |
| Datenhaltung | PostgreSQL (`pg`) | ACID-Transaktionen für das Ledger |
| Auth | `jose` (JWT + Apple-JWKS) | Standard, kein Eigenbau der Krypto |
| Sessions | eigenes JWT (HS256) | zustandslos; Secret später aus Key Vault |

Der Coin-Stand: `SELECT SUM(amount) FROM ledger_entries WHERE account_id = …`.
Jede Buchung trägt einen `idempotency_key` (global eindeutig) und einen unter Sperre
berechneten `balance_after` (Audit). Belastungen sperren die Konto-Zeile (`FOR UPDATE`),
prüfen den Saldo und verhindern so ein Überziehen auch bei parallelen Requests.

## Lokal starten

```bash
npm install
docker compose up -d postgres        # Postgres auf :5432
export DATABASE_URL=postgres://arena:arena@localhost:5432/arena
npm run migrate                      # Schema anlegen
npm run dev                          # API auf :8080
```

## Tests (echte Postgres, Integritäts-Nachweis)

```bash
docker compose up -d postgres
export DATABASE_URL=postgres://arena:arena@localhost:5432/arena
npm test
```

Die Tests belegen u. a.: Idempotenz (kein Doppel-Effekt), atomares Rollback bei
Teilfehler, **30 parallele Belastungen können den Saldo nie negativ machen**, und die
Gast→Apple-Migration erhält den Coin-Stand.

## API (Stand Fundament)

| Methode | Pfad | Auth | Zweck |
|---|---|---|---|
| GET | `/health` | – | Liveness + DB-Ping |
| POST | `/auth/guest` | – | Gast-Konto + Willkommensbonus (1.000) |
| POST | `/auth/apple` | – | Sign in with Apple (`{identityToken, guestToken?}`) |
| GET | `/me` | Bearer | Konto-Infos + Saldo |
| GET | `/wallet` | Bearer | Saldo |
| GET | `/wallet/history` | Bearer | letzte Buchungen |
| POST | `/wallet/demo-grant` | Bearer | +100.000 (nur dev) |
| GET | `/matches` | – | anstehende Spiele + Server-Quoten (1X2, OU25) |
| GET | `/outrights` | – | Turniersieger-Quoten je Wettbewerb |
| POST | `/bets` | Bearer | Wette platzieren (`{stake, legs:[{matchId,market,pick}], idempotencyKey}`) |
| GET | `/bets` | Bearer | eigene Wetten (mit Legs) |
| GET | `/bets/:id` | Bearer | einzelne eigene Wette |
| GET | `/league/current` | – | aktuelle ARENA-Liga-Runde (Quoten, Kickoff, Settle-Zeit) |
| GET | `/engagement` | Bearer | XP/Level, Freispiele, Serie, Bonus-Timer, Max-Einsatz |
| POST | `/bonus/claim` | Bearer | 3h-Bonus abholen (jeder 3. Claim: Rad, server-gedreht) |
| POST | `/spins/play` | Bearer | Freispiel einlösen (Server-RNG, Gewinn über Ledger) |
| POST | `/stadium/:part/upgrade` | Bearer | Stadion-Ausbau (tribune/flutlicht/rasen/fanshop) |
| POST | `/tipp` | Bearer | Tages-Tipp auf die aktuelle Liga-Runde (`{pick:"1"|"X"|"2"}`) |
| POST | `/admin/matches/:id/result` | x-admin-key | Ergebnis verbuchen → Auto-Settlement |
| POST | `/admin/matches/:id/void` | x-admin-key | Spiel annullieren → Erstattung |
| POST | `/admin/sync-odds` | x-admin-key | Quoten-Feed sofort ingestieren |

Hintergrund-Jobs: Quoten-Sync (alle `ODDS_SYNC_SECONDS`, Default 120 s) und Wartung
(`MAINTENANCE_SECONDS`, Default 300 s: Recovery-Sweep + Auto-Void nach
`VOID_STALE_AFTER_HOURS`, Default 48 h). Die Admin-Endpunkte sind der B4-Übergang:
der echte Ergebnis-Feed ruft später exakt dieselbe Settlement-Engine auf.

Der B3-Code wurde einer **adversarialen Multi-Linsen-Review** unterzogen (Korrektheit,
Nebenläufigkeit, Security, Ökonomie-Vertrag; jedes Finding von 3 unabhängigen Skeptikern
verifiziert). Alle 8 bestätigten Findings sind gefixt und mit Regressionstests belegt
(u. a. user-gebundene Idempotenz-Keys, 23505-Race, Crash-Recovery, Signup-Bonus bei
direktem Apple-Login, Ingest-Robustheit, JWT-Produktions-Guard).

## Als Nächstes (Phase B)

- **B4** Ergebnis-Feed → Auto-Settlement (ersetzt die Admin-Ergebnis-Endpunkte;
  blockiert durch A3 Sportdaten-Vertrag — Engine ist fertig und feed-agnostisch).
- **B5** ARENA-Liga-Engine serverseitig (RNG-Audit, WebSocket-Fanout).
- Danach: Redis (Rate-Limits/Sessions), IAP-Receipt-Validierung (B9), RG serverseitig (B10).

> Deployment nach Azure (Germany West Central, Postgres Flexible Server) ist **bewusst
> noch nicht erfolgt** — das verursacht laufende Kosten und wird erst nach Freigabe
> gemacht (Go-Live-Plan B13).
