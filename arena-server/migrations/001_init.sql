-- ARENA Backend – Schema-Fundament (Phase B1/B2)
-- Kernprinzip: KEIN veränderliches `coins`-Feld. Der Coin-Stand ergibt sich
-- ausschließlich aus der Summe der append-only Ledger-Buchungen. Das macht das
-- Wallet server-autoritativ, auditierbar und gegen Client-Manipulation immun.

create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- Nutzer / Accounts
-- ---------------------------------------------------------------------------
create table if not exists users (
  id            uuid primary key default gen_random_uuid(),
  kind          text not null check (kind in ('guest', 'apple')),
  apple_sub     text unique,                         -- Apple „sub“ (stabile User-ID), nur bei kind='apple'
  display_name  text not null default 'Spieler',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Ledger (append-only, doppelte Buchführung je Konto)
--   amount: signed – positiv = Gutschrift (Faucet), negativ = Belastung (Sink)
--   idempotency_key: global eindeutig → sichere Wiederholung bei Retries
--   balance_after: unter Sperre berechneter Kontostand-Snapshot (Audit/Debug)
-- ---------------------------------------------------------------------------
create table if not exists ledger_entries (
  id               bigint generated always as identity primary key,
  account_id       uuid not null references users(id),
  amount           bigint not null,
  reason           text not null,          -- z. B. signup_bonus, bonus_claim, bet_stake, bet_payout, duel_rake, iap …
  ref_type         text,                   -- z. B. 'bet', 'duel', 'iap'
  ref_id           text,
  idempotency_key  text not null unique,
  balance_after    bigint not null check (balance_after >= 0),
  created_at       timestamptz not null default now()
);

create index if not exists ledger_account_idx on ledger_entries (account_id, id desc);
