// Pure functions that turn raw Cashpoint game objects into the ARENA target
// schema. No I/O here so this file is unit-testable in isolation.

// Cashpoint stores odds as integers scaled by 100 (e.g. 230 => 2.30).
const ODDS_SCALE = 100;

export function toDecimal(rawOdds) {
  if (typeof rawOdds !== 'number' || !Number.isFinite(rawOdds)) return null;
  // Keep 2 decimals; round away binary float noise (2.3300000000000005 -> 2.33).
  return Math.round((rawOdds / ODDS_SCALE) * 100) / 100;
}

// First three ASCII alphanumerics of a name, diacritics folded, lower-cased.
// "Frankreich" -> "fra", "Bayern München" -> "bay", "1. FC Köln" -> "1fc".
// Combining diacritical marks block U+0300–U+036F (built without literal
// combining chars so the source stays plain ASCII / encoding-proof).
const COMBINING_MARKS = new RegExp('[\\u0300-\\u036f]', 'g');

export function slug3(name) {
  const ascii = String(name || '')
    .normalize('NFKD')
    .replace(COMBINING_MARKS, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
  return ascii.slice(0, 3) || 'xxx';
}

function isoDate(kickoffIso) {
  const d = new Date(kickoffIso);
  if (Number.isNaN(d.getTime())) return '0000-00-00';
  return d.toISOString().slice(0, 10); // UTC date
}

export function buildMatchId(competitionId, home, away, kickoffIso) {
  return `${competitionId}-${isoDate(kickoffIso)}-${slug3(home)}-${slug3(away)}`;
}

function teamName(team) {
  const n = team?.name;
  // If name resolution failed the field is a numeric translation ID — treat as
  // unusable so such games are skipped rather than emitting garbage.
  if (typeof n === 'string' && n.trim()) return n.trim();
  return null;
}

// --- Market extractors --------------------------------------------------

// 1X2: primary "Wer gewinnt das Spiel" market with tips labelled 1 / X / 2.
export function extract1x2(markets) {
  const candidates = (markets || []).filter((m) => {
    if (m == null) return false;
    // Handicap markets also carry 1/X/2 tips — exclude them (they set `hc`).
    if (m.hc != null || m.hcAnchor != null) return false;
    const tips = m.tips || [];
    if (tips.length !== 3) return false;
    const labels = new Set(tips.map((t) => String(t.text).trim().toUpperCase()));
    return labels.has('1') && labels.has('X') && labels.has('2');
  });
  if (candidates.length === 0) return null;

  // Prefer the primary full-time market.
  candidates.sort((a, b) => score1x2(b) - score1x2(a));
  const m = candidates[0];

  const byLabel = {};
  for (const t of m.tips) byLabel[String(t.text).trim().toUpperCase()] = toDecimal(t.odds);
  const out = { 1: byLabel['1'], X: byLabel['X'], 2: byLabel['2'] };
  if (out['1'] == null || out.X == null || out['2'] == null) return null;
  return out;
}

function score1x2(m) {
  let s = 0;
  if (m.isPrimary) s += 100;
  if ((m.categoryIds || []).includes(1)) s += 10;
  if ((m.subcategoryIds || []).includes(1)) s += 5;
  if (/wer gewinnt das spiel/i.test(m.text || '')) s += 20;
  return s;
}

// The goal-line of an over/under market: from `placeholders` when present
// (WM feed, e.g. "2.5"), otherwise parsed from the German text ("… - 2,5").
function ouLine(m) {
  const ph = (m.placeholders || []).map((p) => String(p).replace(',', '.'));
  if (ph.length) return ph[0];
  const mm = String(m.text || '').match(/(\d+)[.,](\d+)/);
  return mm ? `${mm[1]}.${mm[2]}` : null;
}

// Over/Under 2.5 total goals (full match). The full-match total-goals family is
// category 2 / subcategory 9. Half-time variants also contain category 5 and
// are excluded, as are team-specific / combined markets (different text or
// subcategory). The 2.5 line comes from placeholders or the text.
export function extractOu25(markets) {
  const m = (markets || []).find((mk) => {
    if (mk == null) return false;
    const cats = mk.categoryIds || [];
    const subs = mk.subcategoryIds || [];
    return (
      cats.includes(2) &&
      !cats.includes(5) && // 5 marks half-time / period markets
      subs.includes(9) &&
      /^\s*over\s*\+\s*\/\s*under/i.test(mk.text || '') && // main total-goals O/U only
      ouLine(mk) === '2.5' &&
      (mk.tips || []).length >= 2
    );
  });
  if (!m) return null;

  // Over tip ends with "+", under tip is a range like "0-2". Fall back to order.
  let over = m.tips.find((t) => /\+$/.test(String(t.text).trim()));
  let under = m.tips.find((t) => /^\d+\s*-\s*\d+$/.test(String(t.text).trim()));
  if (!over) over = m.tips[0];
  if (!under) under = m.tips[1];

  const o = toDecimal(over?.odds);
  const u = toDecimal(under?.odds);
  if (o == null || u == null) return null;
  return { over: o, under: u };
}

// --- Game / competition assembly ---------------------------------------

export function normalizeMatch(game, competitionId) {
  const teams = game?.teams || [];
  const home = teamName(teams.find((t) => t.order === 0) || teams[0]);
  const away = teamName(teams.find((t) => t.order === 1) || teams[1]);
  if (!home || !away) return null;

  const kickoff = game.startTime || null;
  const odds1x2 = extract1x2(game.markets);
  const ou25 = extractOu25(game.markets);

  return {
    id: buildMatchId(competitionId, home, away, kickoff),
    home,
    away,
    kickoff,
    venue: null, // not provided by the Cashpoint feed (see DISCOVERY.md)
    odds1x2: odds1x2 || null,
    ou25: ou25 || null,
    _sourceGameId: game.id, // internal; stripped before output
  };
}

// Long-term "winner" league: each game is a single team with one "Sieg" tip.
export function normalizeOutrights(games) {
  const out = [];
  for (const g of games || []) {
    const team = teamName((g.teams || [])[0]);
    const tip = g?.markets?.[0]?.tips?.[0];
    const odds = toDecimal(tip?.odds);
    if (!team || odds == null) continue;
    out.push({ team, odds });
  }
  out.sort((a, b) => a.odds - b.odds); // favourites first
  return out;
}

// Sort by kickoff ascending and keep only upcoming games, capped to `max`.
export function selectUpcoming(matches, max, now = Date.now()) {
  const grace = 60 * 60 * 1000; // keep games until 1h after kickoff
  return matches
    .filter((m) => {
      const t = Date.parse(m.kickoff);
      return Number.isFinite(t) ? t >= now - grace : true;
    })
    .sort((a, b) => Date.parse(a.kickoff) - Date.parse(b.kickoff))
    .slice(0, max);
}

// Remove internal helper fields before serialising.
export function cleanMatch(m) {
  const { _sourceGameId, ...rest } = m;
  return rest;
}
