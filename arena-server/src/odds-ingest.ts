import { pool } from "./db.js";
import { config } from "./config.js";
import { voidMatch } from "./settlement.js";

// ---------------------------------------------------------------------------
// Odds-Ingest: holt den Feed unseres Frankfurt-Fetchers und upsertet `matches`.
// Der Server wird damit zur autoritativen Quoten-Quelle für die Wett-Platzierung.
// ---------------------------------------------------------------------------

export interface FeedMatch {
  id: string;
  home: string;
  away: string;
  kickoff: string; // ISO
  odds1x2?: Record<string, number> | null; // {"1":2.3,"X":3.25,"2":3.31}
  ou25?: { over?: number; under?: number } | null;
}

export interface FeedOutright {
  team: string;
  odds: number;
}

export interface FeedCompetition {
  id: string;
  name: string;
  matches?: FeedMatch[];
  outrights?: FeedOutright[];
}

export interface FeedDoc {
  source?: string;
  fetchedAt?: string;
  stale?: boolean;
  competitions?: FeedCompetition[];
}

/** Feed-Match → Markt-Struktur, wie sie in matches.odds (jsonb) liegt. */
function toMarkets(m: FeedMatch): Record<string, Record<string, number>> {
  const markets: Record<string, Record<string, number>> = {};
  const one = m.odds1x2;
  if (one && [one["1"], one["X"], one["2"]].every((v) => typeof v === "number" && v > 1)) {
    markets["1X2"] = { "1": one["1"]!, X: one["X"]!, "2": one["2"]! };
  }
  const ou = m.ou25;
  if (ou && typeof ou.over === "number" && typeof ou.under === "number" && ou.over > 1 && ou.under > 1) {
    markets["OU25"] = { over: ou.over, under: ou.under };
  }
  return markets;
}

export interface IngestResult {
  upserted: number;
  skipped: number;
  errors: number;
  outrights: number;
  voidedVanished: number;
  outrightsRemoved: number;
}

/**
 * Feed-Dokument in matches + outrights upserten.
 * - Nur Spiele mit parsebarem Kickoff und mindestens einem gültigen Markt.
 * - Fehler eines EINZELNEN Datensatzes brechen den Lauf NICHT ab (Review-Finding:
 *   sonst veralten alle nachfolgenden Quoten schleichend an einem kaputten Eintrag).
 * - `odds_version` erhöht sich genau dann, wenn sich die Quoten ändern (Audit).
 * - Bereits abgerechnete/annullierte Spiele werden NIE mehr überschrieben.
 */
export async function ingestOdds(feed: FeedDoc): Promise<IngestResult> {
  let upserted = 0;
  let skipped = 0;
  let errors = 0;
  let outrights = 0;
  let voidedVanished = 0;
  let outrightsRemoved = 0;
  let firstError: string | undefined;

  for (const comp of feed.competitions ?? []) {
    const validIds: string[] = [];
    let maxKickoff = 0;

    for (const m of comp.matches ?? []) {
      const markets = toMarkets(m);
      if (!m.id || !m.home || !m.away || !m.kickoff || Number.isNaN(Date.parse(m.kickoff)) || Object.keys(markets).length === 0) {
        skipped++;
        continue;
      }
      validIds.push(m.id);
      maxKickoff = Math.max(maxKickoff, Date.parse(m.kickoff));
      try {
        const res = await pool.query(
          `insert into matches (id, competition_id, competition_name, home, away, kickoff, odds)
           values ($1, $2, $3, $4, $5, $6, $7)
           on conflict (id) do update set
             competition_name = excluded.competition_name,
             home = excluded.home,
             away = excluded.away,
             kickoff = excluded.kickoff,
             odds = excluded.odds,
             odds_version = matches.odds_version
               + case when matches.odds is distinct from excluded.odds then 1 else 0 end,
             odds_updated_at = case when matches.odds is distinct from excluded.odds
               then now() else matches.odds_updated_at end
           where matches.status = 'scheduled'`,
          [m.id, comp.id, comp.name, m.home, m.away, m.kickoff, JSON.stringify(markets)],
        );
        if (res.rowCount) upserted++;
        else skipped++; // Spiel existiert, ist aber schon finished/void → unangetastet
      } catch (err) {
        errors++;
        firstError ??= `${m.id}: ${(err as Error).message}`;
      }
    }

    // Outright-Quoten (Turniersieger) – App-Markt "WIN" (Anzeige; Wetten folgen mit B4+).
    for (const o of comp.outrights ?? []) {
      if (!o.team || typeof o.odds !== "number" || o.odds <= 1) continue;
      try {
        await pool.query(
          `insert into outrights (id, competition_id, competition_name, team, odds)
           values ($1, $2, $3, $4, $5)
           on conflict (id) do update set
             odds = excluded.odds,
             competition_name = excluded.competition_name,
             odds_updated_at = case when outrights.odds is distinct from excluded.odds
               then now() else outrights.odds_updated_at end`,
          [`${comp.id}:${o.team}`, comp.id, comp.name, o.team, o.odds.toFixed(4)],
        );
        outrights++;
      } catch (err) {
        errors++;
        firstError ??= `outright ${comp.id}:${o.team}: ${(err as Error).message}`;
      }
    }

    // Review-Finding (belegt an realen Snapshots): Kickoff-Verschiebungen prägen
    // NEUE Match-IDs — die alte Zeile bliebe sonst als wettbares Duplikat mit
    // eingefrorenen Quoten stehen. Deshalb: geplante, zukünftige Spiele dieses
    // Wettbewerbs, die im vom Feed abgedeckten Zeitfenster liegen, aber nicht
    // mehr im Feed vorkommen, annullieren (Einsätze fließen zurück). Spiele
    // JENSEITS des Feed-Horizonts bleiben unangetastet (Feed listet nur die
    // nächsten ~10 — was dahinter liegt, ist nicht "verschwunden").
    if (validIds.length > 0) {
      try {
        // Bewusst STRIKT kleiner: Spiele exakt AM Horizont (z. B. Konferenz-
        // Kickoffs, die der Top-10-Cap des Feeds abschneidet) bleiben unangetastet.
        const { rows: vanished } = await pool.query<{ id: string }>(
          `select id from matches
           where competition_id = $1 and status = 'scheduled'
             and kickoff > now() and kickoff < to_timestamp($2 / 1000.0)
             and not (id = any($3))`,
          [comp.id, maxKickoff, validIds],
        );
        for (const v of vanished) {
          await voidMatch(v.id);
          voidedVanished++;
          console.log(`[odds-ingest] ${v.id}: aus dem Feed verschwunden (Terminverschiebung/Absage) → annulliert`);
        }
      } catch (err) {
        errors++;
        firstError ??= `vanish-check ${comp.id}: ${(err as Error).message}`;
      }
    }

    // Review-Finding (belegt: Frankreich stand nach dem WM-Aus weiter als Favorit
    // in der Anzeige): Outrights, die der Feed für diesen Wettbewerb nicht mehr
    // listet, löschen — aber nur, wenn der Feed überhaupt Outrights liefert
    // (ein transient leeres Feld darf den Bestand nicht wegwischen).
    const validOutrightIds = (comp.outrights ?? [])
      .filter((o) => o.team && typeof o.odds === "number" && o.odds > 1)
      .map((o) => `${comp.id}:${o.team}`);
    if (validOutrightIds.length > 0) {
      try {
        const del = await pool.query(
          "delete from outrights where competition_id = $1 and not (id = any($2))",
          [comp.id, validOutrightIds],
        );
        outrightsRemoved += del.rowCount ?? 0;
      } catch (err) {
        errors++;
        firstError ??= `outright-cleanup ${comp.id}: ${(err as Error).message}`;
      }
    }
  }

  if (errors) console.warn(`[odds-ingest] ${errors} Datensätze fehlgeschlagen, erster: ${firstError}`);
  return { upserted, skipped, errors, outrights, voidedVanished, outrightsRemoved };
}

/** Feed von der konfigurierten URL laden und ingestieren. */
export async function fetchAndIngest(url: string = config.oddsFeedUrl): Promise<IngestResult & { stale: boolean }> {
  const resp = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  if (!resp.ok) throw new Error(`Odds-Feed HTTP ${resp.status}`);
  const feed = (await resp.json()) as FeedDoc;
  const result = await ingestOdds(feed);
  return { ...result, stale: Boolean(feed.stale) };
}

/** Outrights je Wettbewerb (für die App-Anzeige, Markt "WIN"). */
export async function listOutrights(): Promise<Array<Record<string, unknown>>> {
  const { rows } = await pool.query(
    `select id, competition_id, competition_name, team, odds, odds_updated_at
     from outrights order by competition_id, odds asc`,
  );
  return rows.map((r) => ({
    id: r.id,
    competitionId: r.competition_id,
    competitionName: r.competition_name,
    team: r.team,
    odds: Number(r.odds),
    oddsUpdatedAt: r.odds_updated_at.toISOString(),
  }));
}
