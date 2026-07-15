-- Phase B5 + B7 (Kern): Engagement-Zustand (XP/Level/Bonus/Spins) und
-- Audit-Daten der serverseitigen ARENA Liga.
--
-- Grundsatz bleibt: COINS existieren nur im Ledger. Diese Tabellen halten
-- ausschließlich Nicht-Coin-Zustand (XP, Freispiele, Timer, Seeds).

create table if not exists engagement (
  user_id         uuid primary key references users(id),
  xp              int not null default 0,
  free_spins      int not null default 2,
  cards           int not null default 0,
  ring            int not null default 0,          -- jeder 3. Bonus-Claim dreht das Rad
  streak          int not null default 0,          -- Tages-Serie (Multiplikator)
  last_claim_day  int,                             -- UTC-Tagesnummer des letzten Claims
  bonus_ready_at  timestamptz,                     -- null = sofort bereit
  updated_at      timestamptz not null default now()
);

-- ARENA-Liga-Runden: Audit-Trail der virtuellen Spiele. Das Spiel selbst liegt
-- als normale Zeile in `matches` (competition_id 'arena-liga') – Platzierung und
-- Settlement laufen über exakt dieselbe Maschinerie wie echte Spiele.
create table if not exists league_rounds (
  match_id    text primary key references matches(id),
  seed        bigint not null,                     -- deterministischer RNG-Seed (Audit/Replay)
  q           numeric(6, 4) not null,              -- Heim-Anteil der Torerwartung
  lambda      numeric(6, 4) not null,              -- Gesamt-Torerwartung
  settle_at   timestamptz not null,                -- Kickoff + Live-Dauer
  settled     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists league_rounds_due_idx on league_rounds (settle_at) where not settled;
