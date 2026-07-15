import { config } from "./config.js";
import { migrate, pool } from "./db.js";
import { buildServer } from "./server.js";
import { fetchAndIngest } from "./odds-ingest.js";
import { sweepUndecidedBets, voidStaleMatches } from "./settlement.js";
import { leagueTick } from "./league.js";
import { settleFromProviders } from "./results.js";

async function main(): Promise<void> {
  const applied = await migrate();
  if (applied.length) console.log(`[migrate] angewandt: ${applied.join(", ")}`);

  const app = buildServer();
  await app.listen({ port: config.port, host: "0.0.0.0" });
  console.log(`[arena-server] hört auf :${config.port} (env=${process.env.NODE_ENV ?? "development"})`);

  // Quoten-Sync: einmal beim Start, dann periodisch. Fehler nur loggen –
  // der Server bleibt mit den zuletzt ingestierten Quoten arbeitsfähig.
  let syncTimer: NodeJS.Timeout | undefined;
  if (config.oddsSyncSeconds > 0) {
    const sync = async () => {
      try {
        const r = await fetchAndIngest();
        console.log(`[odds-sync] upserted=${r.upserted} skipped=${r.skipped} stale=${r.stale}`);
      } catch (err) {
        console.warn(`[odds-sync] fehlgeschlagen: ${(err as Error).message}`);
      }
    };
    await sync();
    syncTimer = setInterval(sync, config.oddsSyncSeconds * 1000);
    syncTimer.unref();
  }

  // ARENA Liga: fällige Runden abrechnen + neue Runde offen halten.
  let leagueTimer: NodeJS.Timeout | undefined;
  if (config.leagueTickSeconds > 0) {
    const tick = async () => {
      try {
        await leagueTick();
      } catch (err) {
        console.warn(`[league] Tick fehlgeschlagen: ${(err as Error).message}`);
      }
    };
    await tick();
    leagueTimer = setInterval(tick, config.leagueTickSeconds * 1000);
    leagueTimer.unref();
  }

  // Ergebnis-Zwischenlösung: echte Endstände von OpenLigaDB (WM/BL/DFB) →
  // Auto-Settlement. Nicht abgedeckte Ligen fängt der Auto-Void (48 h) auf.
  let resultsTimer: NodeJS.Timeout | undefined;
  if (config.resultsSyncSeconds > 0) {
    const syncResults = async () => {
      try {
        const n = await settleFromProviders();
        if (n) console.log(`[results] ${n} Spiele automatisch abgerechnet`);
      } catch (err) {
        console.warn(`[results] Sync fehlgeschlagen: ${(err as Error).message}`);
      }
    };
    await syncResults();
    resultsTimer = setInterval(syncResults, config.resultsSyncSeconds * 1000);
    resultsTimer.unref();
  }

  // Wartung: Recovery-Sweep hängender Wetten + Auto-Void verwaister Spiele.
  // Beim Start (Crash-Recovery!) und danach periodisch.
  let maintTimer: NodeJS.Timeout | undefined;
  if (config.maintenanceSeconds > 0) {
    const maintain = async () => {
      try {
        const voided = await voidStaleMatches(config.voidStaleAfterHours);
        const swept = await sweepUndecidedBets();
        if (voided || swept) console.log(`[maintenance] auto-void=${voided} recovery-settled=${swept}`);
      } catch (err) {
        console.warn(`[maintenance] fehlgeschlagen: ${(err as Error).message}`);
      }
    };
    await maintain();
    maintTimer = setInterval(maintain, config.maintenanceSeconds * 1000);
    maintTimer.unref();
  }

  for (const sig of ["SIGINT", "SIGTERM"] as const) {
    process.on(sig, async () => {
      if (syncTimer) clearInterval(syncTimer);
      if (maintTimer) clearInterval(maintTimer);
      if (leagueTimer) clearInterval(leagueTimer);
      if (resultsTimer) clearInterval(resultsTimer);
      await app.close();
      await pool.end();
      process.exit(0);
    });
  }
}

main().catch((err) => {
  console.error("[arena-server] Start fehlgeschlagen:", err);
  process.exit(1);
});
