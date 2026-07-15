import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { config } from "./config.js";

// bigint (Ledger-Beträge) als JS-Number parsen. Coins bleiben klar im sicheren
// Integer-Bereich (Start 1.000 bis einige Mio) – kein BigInt-Handling nötig.
pg.types.setTypeParser(20, (v) => (v === null ? null : Number(v)));

// Azure PostgreSQL Flexible Server erzwingt TLS; `sslmode=require` in der URL
// aktiviert es (Zertifikat chained auf öffentlich vertraute Roots → verifizierbar).
export const pool = new pg.Pool({
  connectionString: config.databaseUrl,
  max: 10,
  ssl: config.databaseUrl.includes("sslmode=require") ? { rejectUnauthorized: false } : undefined,
});

export type Client = pg.PoolClient;

/** Callback in einer Transaktion ausführen (BEGIN/COMMIT, ROLLBACK bei Fehler). */
export async function withTx<T>(fn: (c: Client) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("begin");
    const result = await fn(client);
    await client.query("commit");
    return result;
  } catch (err) {
    await client.query("rollback").catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

// Beliebige, aber feste App-weite Lock-ID für Migrationen.
const MIGRATE_LOCK_ID = 0x41524e41; // "ARNA"

/**
 * Alle noch nicht angewandten SQL-Migrationen in Dateinamen-Reihenfolge ausführen.
 * Ein Postgres-Advisory-Lock serialisiert parallele Instanzen (Rolling Deploy,
 * parallele Testprozesse) – der zweite Prozess wartet und sieht dann alles als
 * bereits angewandt (Review-Finding: vorher Race auf `create table`).
 */
export async function migrate(): Promise<string[]> {
  const lock = await pool.connect();
  try {
    await lock.query("select pg_advisory_lock($1)", [MIGRATE_LOCK_ID]);
    await lock.query(
      `create table if not exists schema_migrations (
         name text primary key,
         applied_at timestamptz not null default now()
       )`,
    );
    const done = new Set(
      (await lock.query<{ name: string }>("select name from schema_migrations")).rows.map((r) => r.name),
    );
    const files = readdirSync(migrationsDir).filter((f) => f.endsWith(".sql")).sort();
    const applied: string[] = [];
    for (const file of files) {
      if (done.has(file)) continue;
      const sql = readFileSync(join(migrationsDir, file), "utf8");
      await withTx(async (c) => {
        await c.query(sql);
        await c.query("insert into schema_migrations (name) values ($1)", [file]);
      });
      applied.push(file);
    }
    return applied;
  } finally {
    await lock.query("select pg_advisory_unlock($1)", [MIGRATE_LOCK_ID]).catch(() => {});
    lock.release();
  }
}
