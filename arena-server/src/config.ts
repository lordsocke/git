// Zentrale Konfiguration aus Umgebungsvariablen. Keine Secrets im Code.
// Für lokale Entwicklung siehe .env.example + docker-compose.yml.

const isProduction = (process.env.NODE_ENV ?? "development") === "production";

function req(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (v === undefined) throw new Error(`Fehlende Umgebungsvariable: ${name}`);
  return v;
}

/** Dev-Fallback, der in Produktion NIEMALS greifen darf (Review-Finding: Token-Fälschung). */
function devOnly(name: string, fallback: string): string {
  if (isProduction && !process.env[name]) {
    throw new Error(`${name} muss in Produktion gesetzt sein – Start verweigert.`);
  }
  return process.env[name] ?? fallback;
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  // Postgres-Verbindung (append-only Ledger = einzige Wahrheit über den Coin-Stand).
  databaseUrl: req("DATABASE_URL", "postgres://arena:arena@localhost:5432/arena"),
  // Signiergeheimnis für unsere eigenen Session-Tokens (HS256). In Prod aus Key Vault.
  jwtSecret: devOnly("JWT_SECRET", "dev-only-insecure-secret-change-me"),
  jwtIssuer: process.env.JWT_ISSUER ?? "arena",
  jwtTtlSeconds: Number(process.env.JWT_TTL_SECONDS ?? 60 * 60 * 24 * 30), // 30 Tage
  // Sign in with Apple: die App-Bundle-ID ist die erwartete Audience des Apple-Tokens.
  appleClientId: process.env.APPLE_CLIENT_ID ?? "de.targetki.arena",
  // Willkommensguthaben (deckungsgleich mit der App: „Start klein → Millionär").
  signupBonusCoins: Number(process.env.SIGNUP_BONUS ?? 1000),
  // Demo-/Dev-Endpunkte (z. B. Coins-Faucet) nur außerhalb Produktion erlauben.
  enableDevEndpoints: !isProduction,

  // --- Wetten (B3) ---
  // Quoten-Feed (unser Frankfurt-Fetcher). Der Server ingestiert daraus `matches`.
  oddsFeedUrl: process.env.ODDS_FEED_URL ?? "https://arena-odds-de.azurewebsites.net/odds",
  // Sync-Intervall in Sekunden (0 = kein automatischer Sync, z. B. in Tests).
  oddsSyncSeconds: Number(process.env.ODDS_SYNC_SECONDS ?? 120),
  // Wartungs-Intervall: Recovery-Sweep offener, aber entschiedener Wetten +
  // Auto-Void verwaister Spiele (0 = aus, z. B. in Tests).
  maintenanceSeconds: Number(process.env.MAINTENANCE_SECONDS ?? 300),
  // Spiele ohne Ergebnis-Eingang: nach Kickoff + X Stunden automatisch annullieren
  // (Einsätze fließen zurück) statt Wetten ewig offen zu lassen.
  voidStaleAfterHours: Number(process.env.VOID_STALE_AFTER_HOURS ?? 48),

  // --- Ergebnis-Zwischenlösung (B4-Übergang, OpenLigaDB) ---
  resultsSyncSeconds: Number(process.env.RESULTS_SYNC_SECONDS ?? 600),

  // --- Engagement (B7-Kern) ---
  bonusCooldownHours: Number(process.env.BONUS_COOLDOWN_HOURS ?? 3),

  // --- ARENA Liga (B5) ---
  // Taktung wie Produkt-Konzept: ~45 s Wettfenster + ~90 s "live" ⇒ Zyklus ~135 s.
  // leagueTickSeconds 0 = Engine aus (Tests treiben sie manuell).
  leagueTickSeconds: Number(process.env.LEAGUE_TICK_SECONDS ?? 5),
  leagueBettingSeconds: Number(process.env.LEAGUE_BETTING_SECONDS ?? 45),
  leagueLiveSeconds: Number(process.env.LEAGUE_LIVE_SECONDS ?? 90),
  // Einsatz-Leitplanken. Das level-abhängige Max kommt mit dem Engagement-Service (B7);
  // bis dahin gilt das globale App-Maximum (Cap der maxStake-Kurve, L55 ≈ 150 T < 1 Mio).
  minStake: Number(process.env.MIN_STAKE ?? 10),
  maxStake: Number(process.env.MAX_STAKE ?? 1_000_000),
  maxComboLegs: Number(process.env.MAX_COMBO_LEGS ?? 4),
  // Admin-Key für Ergebnis-/Sync-Endpunkte (B4-Übergang). In Produktion MUSS er via
  // Env gesetzt sein – ohne Wert sind die Admin-Endpunkte deaktiviert.
  adminKey: process.env.ADMIN_KEY ?? (isProduction ? "" : "dev-admin"),
} as const;
