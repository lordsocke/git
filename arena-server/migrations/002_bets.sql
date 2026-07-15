-- Phase B3: Matches (aus dem Quoten-Feed), Wetten und Wett-Legs.
-- Prinzipien:
--   * Der Server ist die QUELLE der Quoten – der Client sendet nur (match, market, pick),
--     bepreist wird ausschließlich aus `matches.odds` (server-autoritativ).
--   * Geldbewegungen laufen NUR über das Ledger (bet_stake / bet_payout / bet_void).
--   * Settlement ist idempotent: Legs werden nur aus Status 'open' heraus entschieden,
--     Auszahlungen tragen deterministische Idempotenz-Keys (`bet:<id>:payout`).

create table if not exists matches (
  id                text primary key,               -- Feed-ID, z. B. 'wm-2026-07-14-fra-spa'
  competition_id    text not null,                  -- z. B. 'wm', 'bl'
  competition_name  text not null,
  home              text not null,
  away              text not null,
  kickoff           timestamptz not null,
  status            text not null default 'scheduled'
                    check (status in ('scheduled', 'finished', 'void')),
  result_home       int,
  result_away       int,
  odds              jsonb not null default '{}'::jsonb,  -- {"1X2":{"1":2.3,"X":3.25,"2":3.31},"OU25":{"over":1.87,"under":1.87}}
  odds_version      int not null default 1,             -- erhöht sich bei jeder Quotenänderung (Audit)
  odds_updated_at   timestamptz not null default now(),
  settled_at        timestamptz,
  created_at        timestamptz not null default now()
);

create index if not exists matches_status_kickoff_idx on matches (status, kickoff);

create table if not exists bets (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references users(id),
  stake            bigint not null check (stake > 0),
  total_odds       numeric(12, 4) not null,
  status           text not null default 'open'
                   check (status in ('open', 'won', 'lost', 'void')),
  payout           bigint,
  idempotency_key  text not null unique,           -- Client-Key: Platzierung Retry-sicher
  placed_at        timestamptz not null default now(),
  settled_at       timestamptz
);

create index if not exists bets_user_idx on bets (user_id, placed_at desc);
create index if not exists bets_open_idx on bets (status) where status = 'open';

create table if not exists bet_legs (
  id            bigint generated always as identity primary key,
  bet_id        uuid not null references bets(id),
  match_id      text not null references matches(id),
  market        text not null check (market in ('1X2', 'OU25')),
  pick          text not null,                     -- '1'|'X'|'2' bzw. 'over'|'under'
  odds          numeric(10, 4) not null,           -- Quoten-Snapshot zum Platzierungszeitpunkt
  odds_version  int not null,                      -- Audit: gegen welche Quotenversion platziert
  status        text not null default 'open'
                check (status in ('open', 'won', 'lost', 'void')),
  unique (bet_id, match_id, market)                -- je Wette max. 1 Markt pro Spiel
);

create index if not exists bet_legs_open_match_idx on bet_legs (match_id) where status = 'open';
create index if not exists bet_legs_bet_idx on bet_legs (bet_id);
