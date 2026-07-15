// Resolves the configured competitions to concrete Cashpoint league IDs by
// matching league names from getFilters against each competition's pattern.
// Falls back to the hard-coded IDs when nothing matches.
import { SPORT_FOOTBALL, COMPETITIONS, MATCH_GAME_TYPES } from './config.js';
import { log } from './logger.js';

// Returns a Map<competitionId, { matchLeagueIds:number[], outrightLeagueIds:number[] }>
export async function resolveLeagues(client, jurisdictionId) {
  let leagues = [];
  try {
    // Ask for a broad set of game types so long-term (outright) leagues are
    // included in the catalogue too.
    const filters = await client.getFilters([...MATCH_GAME_TYPES, 5], jurisdictionId);
    leagues = Array.isArray(filters?.leagues) ? filters.leagues : [];
  } catch (err) {
    log.warn('league resolution: getFilters failed, using fallback IDs', err.message);
  }

  const football = leagues.filter((l) => l && l.sportId === SPORT_FOOTBALL);
  const resolved = new Map();

  for (const comp of COMPETITIONS) {
    const matchMatches = football.filter(
      (l) => !l.longTerm && comp.matchPattern.test(l.name || ''),
    );
    let matchLeagueIds = matchMatches
      .sort((a, b) => (b.prematchGameCount || 0) - (a.prematchGameCount || 0))
      .map((l) => l.id);

    if (matchLeagueIds.length === 0) {
      matchLeagueIds = comp.fallbackLeagueIds.slice();
      log.debug(`comp ${comp.id}: no live match for pattern, fallback -> ${matchLeagueIds.join(',')}`);
    } else {
      log.debug(
        `comp ${comp.id}: matched ${matchMatches.map((l) => `${l.id}"${l.name}"`).join(', ')}`,
      );
    }

    let outrightLeagueIds = [];
    if (comp.outright) {
      const outrightMatches = football.filter(
        (l) => l.longTerm && comp.outright.pattern.test(l.name || ''),
      );
      outrightLeagueIds = outrightMatches.map((l) => l.id);
      if (outrightLeagueIds.length === 0) outrightLeagueIds = comp.outright.fallbackLeagueIds.slice();
    }

    resolved.set(comp.id, { matchLeagueIds, outrightLeagueIds });
  }

  return resolved;
}
