import type { Client } from "./db.js";
import { pool, withTx } from "./db.js";

// ---------------------------------------------------------------------------
// Ledger-Wallet: server-autoritativer Coin-Stand aus append-only Buchungen.
// Der Saldo ist NIE ein gespeicherter Wert, sondern SUM(amount) über das Ledger.
// ---------------------------------------------------------------------------

/** Erlaubte Buchungsgründe (Faucets positiv, Sinks negativ). Erweiterbar je Feature. */
export type LedgerReason =
  | "signup_bonus"
  | "bonus_claim"
  | "wheel"
  | "freespin_win"
  | "challenge"
  | "chest"
  | "tipp"
  | "levelup"
  | "bet_stake"
  | "bet_payout"
  | "bet_void"
  | "duel_stake"
  | "duel_payout"
  | "duel_rake"
  | "iap"
  | "stadium"
  | "admin_demo";

export interface PostSpec {
  amount: number; // signed: >0 Gutschrift, <0 Belastung
  reason: LedgerReason;
  idempotencyKey: string; // global eindeutig; identischer Key = derselbe Effekt (Retry-sicher)
  refType?: string;
  refId?: string;
}

export interface LedgerResult {
  entryId: number | null; // null, wenn per Idempotenz auf eine bestehende Buchung getroffen
  balance: number; // Kontostand NACH Anwendung
  duplicate: boolean; // true = Buchung existierte bereits (kein neuer Effekt)
}

export class InsufficientFundsError extends Error {
  constructor(
    public readonly needed: number,
    public readonly available: number,
  ) {
    super(`Nicht genug Coins: benötigt ${needed}, verfügbar ${available}`);
    this.name = "InsufficientFundsError";
  }
}

/** Aktuellen Kontostand lesen (Summe des Ledgers). */
export async function getBalance(accountId: string, client?: Client): Promise<number> {
  const runner = client ?? pool;
  const { rows } = await runner.query<{ balance: number }>(
    "select coalesce(sum(amount), 0)::bigint as balance from ledger_entries where account_id = $1",
    [accountId],
  );
  return rows[0]?.balance ?? 0;
}

/**
 * Kern der Buchungslogik – läuft in einer BESTEHENDEN Transaktion (Client `c`).
 * Für zusammengesetzte Abläufe (z. B. Wette anlegen + Einsatz abbuchen atomar).
 * - Sperrt die Konto-Zeile (FOR UPDATE) → serialisiert konkurrierende Belastungen.
 * - Idempotenz: bekannter Key wird übersprungen (kein Doppel-Effekt).
 * - Schutz: der Kontostand darf zu keinem Zeitpunkt negativ werden.
 * Reihenfolge der specs wird eingehalten (z. B. erst Rake abziehen, dann auszahlen).
 */
export async function postManyIn(c: Client, accountId: string, specs: PostSpec[]): Promise<LedgerResult[]> {
  // Konto-Zeile sperren – serialisiert alle Buchungen dieses Kontos.
  const locked = await c.query("select id from users where id = $1 for update", [accountId]);
  if (locked.rowCount === 0) throw new Error(`Unbekanntes Konto: ${accountId}`);

  let balance = await getBalance(accountId, c);
  const results: LedgerResult[] = [];

  for (const spec of specs) {
    // Idempotenz: existiert eine Buchung mit diesem Key bereits?
    const existing = await c.query<{ id: number; balance_after: number }>(
      "select id, balance_after from ledger_entries where idempotency_key = $1",
      [spec.idempotencyKey],
    );
    if (existing.rowCount && existing.rows[0]) {
      // Kein neuer Effekt. Kontostand nicht verändern.
      results.push({ entryId: existing.rows[0].id, balance, duplicate: true });
      continue;
    }

    const next = balance + spec.amount;
    if (next < 0) throw new InsufficientFundsError(-spec.amount, balance);

    const inserted = await c.query<{ id: number }>(
      `insert into ledger_entries (account_id, amount, reason, ref_type, ref_id, idempotency_key, balance_after)
       values ($1, $2, $3, $4, $5, $6, $7)
       returning id`,
      [accountId, spec.amount, spec.reason, spec.refType ?? null, spec.refId ?? null, spec.idempotencyKey, next],
    );
    balance = next;
    results.push({ entryId: inserted.rows[0]!.id, balance, duplicate: false });
  }
  return results;
}

/** Mehrere Buchungen für EIN Konto atomar anwenden (eigene Transaktion). */
export async function postMany(accountId: string, specs: PostSpec[]): Promise<LedgerResult[]> {
  return withTx((c) => postManyIn(c, accountId, specs));
}

/** Eine einzelne Buchung (Gutschrift oder Belastung). */
export async function post(accountId: string, spec: PostSpec): Promise<LedgerResult> {
  const [result] = await postMany(accountId, [spec]);
  return result!;
}

export interface HistoryRow {
  id: number;
  amount: number;
  reason: string;
  refType: string | null;
  refId: string | null;
  balanceAfter: number;
  createdAt: string;
}

/** Letzte Buchungen eines Kontos (für Transaktions-Historie in der App). */
export async function history(accountId: string, limit = 50): Promise<HistoryRow[]> {
  const { rows } = await pool.query(
    `select id, amount, reason, ref_type, ref_id, balance_after, created_at
     from ledger_entries where account_id = $1 order by id desc limit $2`,
    [accountId, Math.min(limit, 200)],
  );
  return rows.map((r) => ({
    id: r.id,
    amount: r.amount,
    reason: r.reason,
    refType: r.ref_type,
    refId: r.ref_id,
    balanceAfter: r.balance_after,
    createdAt: r.created_at.toISOString(),
  }));
}
