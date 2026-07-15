// Orchestrates one full refresh: resolve league IDs, fetch games per
// competition, normalize, and assemble the target-schema document.
// Seit 15.07.2026 auf die offizielle Oddsservice-Doku (v0.5) ausgerichtet:
// WM über Container 283, Match-Requests markt-gefiltert (1X2 + OU 2,5).
import {
  COMPETITIONS,
  MATCH_GAME_TYPES,
  OUTRIGHT_GAME_TYPES,
  MATCH_MARKET_IDS,
  MAX_MATCHES_PER_COMPETITION,
  SOURCE_LABEL,
} from './config.js';
import { resolveLeagues } from './leagueResolver.js';
import {
  normalizeMatch,
  normalizeOutrights,
  selectUpcoming,
  cleanMatch,
} from './normalize.js';
import { log } from './logger.js';

// Thrown when nothing at all could be fetched (treated as a failed refresh so
// the caller keeps serving the last good snapshot as stale).
export class TotalFetchError extends Error {}

// Match-Games eines Wettbewerbs laden: primär über den offiziellen Container
// (falls konfiguriert), sonst/ersatzweise über die aufgelösten Liga-IDs.
// Review-Finding: Der Liga-Fallback muss auch greifen, wenn der Container-Request
// FEHLSCHLÄGT (Container sind laut Doku "HIGHLY FLUID") — nicht nur bei leerer Antwort.
async function fetchCompetitionGames(client, comp, matchLeagueIds, jurisdictionId) {
  if (comp.containerId) {
    try {
      const data = await client.getGames(
        { containerIds: [comp.containerId] },
        MATCH_GAME_TYPES,
        jurisdictionId,
        50,
        MATCH_MARKET_IDS,
      );
      const games = Array.isArray(data?.games) ? data.games : [];
      if (games.length > 0) return games;
      log.warn(`comp ${comp.id}: Container ${comp.containerId} leer — Fallback auf Liga-IDs`);
    } catch (err) {
      log.warn(`comp ${comp.id}: Container ${comp.containerId} fehlgeschlagen — Fallback auf Liga-IDs`, err.message);
    }
  }
  if (matchLeagueIds.length === 0) return [];
  const data = await client.getGames(
    { leagueIds: matchLeagueIds },
    MATCH_GAME_TYPES,
    jurisdictionId,
    20,
    MATCH_MARKET_IDS,
  );
  return Array.isArray(data?.games) ? data.games : [];
}

export async function fetchOddsDocument(client, config) {
  const jurisdictionId = config.cp.jurisdictionId;
  const resolved = await resolveLeagues(client, jurisdictionId);

  const competitions = [];
  let attempted = 0;
  let succeeded = 0;

  let rawTotal = 0;
  let matchTotal = 0;

  for (const comp of COMPETITIONS) {
    const ids = resolved.get(comp.id) || { matchLeagueIds: [], outrightLeagueIds: [] };
    const competition = { id: comp.id, name: comp.name, matches: [], outrights: [] };

    // --- matches ---
    if (comp.containerId || ids.matchLeagueIds.length > 0) {
      attempted++;
      try {
        const raw = await fetchCompetitionGames(client, comp, ids.matchLeagueIds, jurisdictionId);
        const normalized = raw.map((g) => normalizeMatch(g, comp.id)).filter(Boolean);
        const upcoming = selectUpcoming(normalized, MAX_MATCHES_PER_COMPETITION);
        competition.matches = upcoming.map(cleanMatch);
        rawTotal += raw.length;
        matchTotal += competition.matches.length;
        if (competition.matches.length === 0) {
          log.warn(`comp ${comp.id}: 0 Spiele (raw ${raw.length}) — Liga tot, Markt-IDs rotiert oder Namensauflösung defekt?`);
        }
        succeeded++;
      } catch (err) {
        // One competition failing must not sink the whole refresh; emit it
        // empty and carry on. Total failure is detected after the loop.
        log.warn(`comp ${comp.id}: match fetch failed`, err.message);
      }
    }

    // --- outrights (only where offered; bewusst OHNE Markt-Filter) ---
    if (ids.outrightLeagueIds && ids.outrightLeagueIds.length > 0) {
      try {
        const data = await client.getGames(
          { leagueIds: ids.outrightLeagueIds },
          OUTRIGHT_GAME_TYPES,
          jurisdictionId,
          50,
        );
        const raw = Array.isArray(data?.games) ? data.games : [];
        competition.outrights = normalizeOutrights(raw);
      } catch (err) {
        log.warn(`comp ${comp.id}: outright fetch failed`, err.message);
        // Outrights are optional — leave empty on failure.
      }
    }

    competitions.push(competition);
    log.debug(
      `comp ${comp.id}: ${competition.matches.length} matches, ${competition.outrights.length} outrights`,
    );
  }

  // If we tried to fetch matches and every single attempt failed, the source is
  // effectively down — signal a failed refresh so the last good stays served.
  if (attempted > 0 && succeeded === 0) {
    throw new TotalFetchError('all competition match fetches failed (source unreachable?)');
  }

  // Review-Finding: Leere Antworten sind KEIN Erfolg. Ein komplett leeres Dokument
  // (Style-Wechsel der Markt-IDs, tote Container+Fallback-Ligen, kaputte Namens-
  // auflösung → alles liefert leer statt Fehler) darf niemals den Last-Good-
  // Snapshot überschreiben — sonst friert der Feed still mit stale:false ein.
  if (attempted > 0 && matchTotal === 0) {
    throw new TotalFetchError(
      rawTotal > 0
        ? `alle ${rawTotal} Roh-Spiele bei der Normalisierung verworfen (Namensauflösung defekt? Header prüfen)`
        : 'alle Wettbewerbe leer (Markt-IDs rotiert? Container/Ligen tot?) — Last-Good bleibt erhalten',
    );
  }

  return {
    source: SOURCE_LABEL,
    fetchedAt: new Date().toISOString(),
    stale: false,
    competitions,
  };
}
