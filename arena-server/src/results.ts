import { pool } from "./db.js";
import { recordResult } from "./settlement.js";

// ---------------------------------------------------------------------------
// Ergebnis-Zwischenlösung (B4-Übergang): OpenLigaDB (keyless, community-gepflegt,
// deutsche Teamnamen — passt zum Cashpoint-Feed). Deckt aktuell WM 2026,
// Bundesliga und DFB-Pokal ab. Nicht abgedeckte Wettbewerbe (PL/LaLiga/CL)
// fängt der 48h-Auto-Void auf (Einsätze fließen zurück), bis der lizenzierte
// Ergebnis-Feed (A3/B4) kommt — der dann einfach diese Provider-Schnittstelle
// ersetzt und weiterhin recordResult() der Settlement-Engine ruft.
// ---------------------------------------------------------------------------

/** Unser Wettbewerbs-Kürzel → OpenLigaDB (leagueShortcut, season). */
const OPENLIGA_MAP: Record<string, { shortcut: string; season: string }> = {
  wm: { shortcut: "wm26", season: "2026" },
  bl: { shortcut: "bl1", season: "2026" },
  dfb: { shortcut: "dfb", season: "2026" },
};

export interface ProviderResult {
  home: string; // Teamname des Providers
  away: string;
  goalsHome: number;
  goalsAway: number;
  kickoff: string; // ISO UTC
}

export type ProviderFetcher = (competitionId: string) => Promise<ProviderResult[]>;

/** Teamnamen fürs Matching normalisieren (Groß-/Kleinschreibung, Diakritika, Füllwörter). */
export function normalizeTeam(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, " ") // erst Satzzeichen weg ("1." → "1"), dann Füllwörter
    .replace(/\b(fc|sc|sv|tsv|vfl|vfb|tsg|rb|ssv|spvgg|1)\b/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function teamsMatch(a: string, b: string): boolean {
  const na = normalizeTeam(a);
  const nb = normalizeTeam(b);
  if (!na || !nb) return false;
  return na === nb || na.includes(nb) || nb.includes(na);
}

/** Standard-Fetcher: fertige Spiele einer Liga von OpenLigaDB. */
export const fetchOpenLigaResults: ProviderFetcher = async (competitionId) => {
  const league = OPENLIGA_MAP[competitionId];
  if (!league) return [];
  const resp = await fetch(`https://api.openligadb.de/getmatchdata/${league.shortcut}/${league.season}`, {
    signal: AbortSignal.timeout(15_000),
  });
  if (!resp.ok) throw new Error(`OpenLigaDB HTTP ${resp.status}`);
  const data = (await resp.json()) as Array<Record<string, unknown>>;
  const results: ProviderResult[] = [];
  for (const m of data) {
    if (!m.matchIsFinished) continue;
    const team1 = (m.team1 as { teamName?: string })?.teamName;
    const team2 = (m.team2 as { teamName?: string })?.teamName;
    const kickoff = (m.matchDateTimeUTC as string) ?? "";
    const all = (m.matchResults as Array<Record<string, unknown>>) ?? [];
    // resultTypeID 2 = Endergebnis; sonst letztes verfügbares Resultat.
    const final = all.find((r) => r.resultTypeID === 2) ?? all[all.length - 1];
    if (!team1 || !team2 || !final) continue;
    const gh = Number(final.pointsTeam1);
    const ga = Number(final.pointsTeam2);
    if (!Number.isInteger(gh) || !Number.isInteger(ga)) continue;
    results.push({ home: team1, away: team2, goalsHome: gh, goalsAway: ga, kickoff });
  }
  return results;
};

const SIX_HOURS_MS = 6 * 3600 * 1000;

/**
 * Offene, überfällige Spiele (Kickoff + 105 min vorbei) gegen Provider-Ergebnisse
 * matchen (normalisierte Teamnamen + Kickoff ±6 h) und über die reguläre
 * Settlement-Engine abrechnen. Idempotent; Fehler je Wettbewerb isoliert.
 */
export async function settleFromProviders(fetcher: ProviderFetcher = fetchOpenLigaResults): Promise<number> {
  const { rows: due } = await pool.query<{ id: string; competition_id: string; home: string; away: string; kickoff: Date }>(
    `select id, competition_id, home, away, kickoff from matches
     where status = 'scheduled' and competition_id <> 'arena-liga'
       and kickoff < now() - interval '105 minutes'
     order by kickoff asc limit 200`,
  );
  if (!due.length) return 0;

  let settled = 0;
  const byComp = new Map<string, typeof due>();
  for (const m of due) {
    if (!byComp.has(m.competition_id)) byComp.set(m.competition_id, []);
    byComp.get(m.competition_id)!.push(m);
  }

  for (const [comp, matches] of byComp) {
    let results: ProviderResult[];
    try {
      results = await fetcher(comp);
    } catch (err) {
      console.warn(`[results] ${comp}: Provider-Fehler: ${(err as Error).message}`);
      continue;
    }
    if (!results.length) continue;

    for (const m of matches) {
      const hit = results.find(
        (r) =>
          teamsMatch(r.home, m.home) &&
          teamsMatch(r.away, m.away) &&
          Math.abs(new Date(r.kickoff).getTime() - m.kickoff.getTime()) <= SIX_HOURS_MS,
      );
      if (!hit) continue;
      try {
        await recordResult(m.id, hit.goalsHome, hit.goalsAway);
        settled++;
        console.log(`[results] ${m.home} – ${m.away}: ${hit.goalsHome}:${hit.goalsAway} (OpenLigaDB)`);
      } catch (err) {
        console.warn(`[results] Settlement ${m.id} fehlgeschlagen: ${(err as Error).message}`);
      }
    }
  }
  return settled;
}
