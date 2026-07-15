-- B7-Rest: Daily Challenges, Stadion (Meta-Sink + Bonus-Boost), Tages-Tipp.
-- Alles Nicht-Coin-Zustand am Engagement; Coins fließen weiter nur übers Ledger.

alter table engagement add column if not exists stadium     jsonb not null default '{}'::jsonb; -- {"tribune":0..5,...}
alter table engagement add column if not exists challenges  jsonb not null default '{}'::jsonb; -- {"day":n,"vals":{},"done":{},"chestDone":bool}
alter table engagement add column if not exists pick_day    int;            -- UTC-Tag des Tages-Tipps
alter table engagement add column if not exists pick_match  text;           -- Liga-Runde, auf die getippt wurde
alter table engagement add column if not exists pick_choice text;           -- '1' | 'X' | '2'
alter table engagement add column if not exists pick_streak int not null default 0;
alter table engagement add column if not exists pick_best   int not null default 0;

-- Auflösung des Tages-Tipps beim Liga-Settlement: alle offenen Picks je Runde finden.
create index if not exists engagement_pick_match_idx on engagement (pick_match) where pick_match is not null;
