-- Outright-Quoten (Turniersieger) aus dem Feed. Die App zeigt sie im Sport-Tab
-- (Markt "WIN"); Wetten darauf kommen mit dem Outright-Settlement (Phase B4+) –
-- bis dahin dient die Tabelle als Server-Gegenstück des App-Features (Anzeige).

create table if not exists outrights (
  id                text primary key,               -- '<competition_id>:<team>'
  competition_id    text not null,
  competition_name  text not null,
  team              text not null,
  odds              numeric(10, 4) not null,
  odds_updated_at   timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

create index if not exists outrights_comp_idx on outrights (competition_id, odds asc);
