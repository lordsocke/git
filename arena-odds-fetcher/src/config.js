// Static, non-secret configuration: the target competitions and how to map
// them onto Cashpoint league IDs.
//
// League IDs on the Cashpoint feed rotate between seasons (e.g. the Champions
// League qualification and group stage carry different IDs). To stay robust we
// resolve league IDs *dynamically* at runtime from POST /odds/getFilters (by
// matching league names against `matchPattern`), and only fall back to the
// hard-coded IDs below when the pattern finds nothing.
//
// The order of this array is the order competitions appear in the output.

export const SPORT_FOOTBALL = 1;

// Cashpoint gameType filters. 1 = pre-match single, 4 = pre-match "top/extended"
// (both used by the site's own sports list). We deliberately omit 2 (live).
export const MATCH_GAME_TYPES = [1, 4];
export const OUTRIGHT_GAME_TYPES = [1, 2, 4, 5];

// Official market IDs (doc "Popular Market IDs", Oddsservice v0.5). Ein Markt
// existiert je nach "Style" des Spiels unter zwei IDs:
//   22242/59252 = "Wer gewinnt das Spiel?" (1X2)
//   22252/60252 = Over/Under mit FIXER 2,5-Linie (live verifiziert: beide Styles
//   führen eine Leiter mit einer ID je Linie, 22252/60252 ist immer exakt 2,5 —
//   die Doku-Bezeichnung "most balanced" ist irreführend). Frühe Pokalrunden
//   bieten upstream teils GAR KEINE O/U-Märkte an → ou25 fehlt dann korrekt.
// Der Filter schrumpft Match-Antworten von ~650 Märkten/Spiel auf genau die
// zwei, die wir konsumieren, und schließt nebenbei die Torschützen-Pseudo-Games
// aus Container 283 aus ("Messi vs Bester Torschütze" trägt keinen 1X2-Markt).
// Outright-Requests bleiben ungefiltert (Sieger-Markt-IDs sind nicht dokumentiert).
export const MATCH_MARKET_IDS = [22242, 59252, 22252, 60252];

export const MAX_MATCHES_PER_COMPETITION = 10;

export const COMPETITIONS = [
  {
    id: 'wm',
    name: 'FIFA WM 2026',
    // Offizieller Container 283 "FIFA World Cup 2026" (Doku v0.5) bündelt alle
    // WM-Ligen (Gruppen + KO) — primäre Quelle; Pattern/Fallback bleiben als Netz.
    containerId: 283,
    // "WM 2026 KO-Phase", "WM 2026 Gruppenphase", etc. — but NOT the long-term
    // outright leagues ("WM 2026 Sieger …") which are handled via `outright`.
    matchPattern: /^wm 2026(?!.*(sieg|sieger|torsch|handschuh|assist|kontinent|ausscheid|zweierwette|tore im)).*$/i,
    fallbackLeagueIds: [33435],
    outright: {
      // Tournament winner ("Turniersieger").
      pattern: /^wm 2026 sieg$/i,
      fallbackLeagueIds: [108895],
    },
  },
  {
    id: 'bl',
    name: 'Bundesliga',
    matchPattern: /^deutschland bundesliga$/i, // excludes "2. Bundesliga", "Österreich Bundesliga"
    fallbackLeagueIds: [6843],
  },
  {
    id: 'pl',
    name: 'Premier League',
    matchPattern: /^england premier league$/i, // excludes "Island/Russland/… Premier League"
    fallbackLeagueIds: [6823],
  },
  {
    id: 'll',
    name: 'La Liga',
    matchPattern: /^spanien la liga$/i,
    fallbackLeagueIds: [6938],
  },
  {
    id: 'cl',
    name: 'UEFA Champions League',
    // Matches the main league and the qualification round; both are merged.
    matchPattern: /uefa champions league/i,
    // 111560 = offizielle ID (Doku v0.5); 19622 = zuvor beobachtete Quali-ID.
    fallbackLeagueIds: [111560, 19622],
  },
  {
    id: 'dfb',
    name: 'DFB-Pokal',
    matchPattern: /^deutschland dfb pokal$/i,
    fallbackLeagueIds: [6847],
  },
];

export const SOURCE_LABEL = 'Cashpoint Oddsservice (offizielle Integration, Doku v0.5)';
