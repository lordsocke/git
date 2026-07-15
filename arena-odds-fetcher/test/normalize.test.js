import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  toDecimal,
  slug3,
  buildMatchId,
  extract1x2,
  extractOu25,
  normalizeMatch,
  normalizeOutrights,
  selectUpcoming,
  cleanMatch,
} from '../src/normalize.js';
import { validateDocument } from '../src/validate.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const load = (f) => JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', f), 'utf8'));
const matchGame = load('match-france-spain.json');
const blGame = load('match-bundesliga.json');
const outrightData = load('outright-wm.json');

test('toDecimal scales integer odds by 100', () => {
  assert.equal(toDecimal(230), 2.3);
  assert.equal(toDecimal(331), 3.31);
  assert.equal(toDecimal(100), 1.0);
  assert.equal(toDecimal(670), 6.7);
  assert.equal(toDecimal(undefined), null);
});

test('slug3 folds diacritics and strips non-alphanumerics', () => {
  assert.equal(slug3('Frankreich'), 'fra');
  assert.equal(slug3('Spanien'), 'spa');
  assert.equal(slug3('Bayern München'), 'bay');
  assert.equal(slug3('VfB Stuttgart'), 'vfb');
  assert.equal(slug3('1. FC Kaiserslautern'), '1fc');
  assert.equal(slug3(''), 'xxx');
});

test('buildMatchId uses competition, UTC date and slugs', () => {
  assert.equal(
    buildMatchId('wm', 'Frankreich', 'Spanien', '2026-07-14T19:00:00Z'),
    'wm-2026-07-14-fra-spa',
  );
});

test('extract1x2 reads the primary 1/X/2 market', () => {
  const odds = extract1x2(matchGame.markets);
  assert.deepEqual(odds, { 1: 2.3, X: 3.25, 2: 3.31 });
});

test('extractOu25 picks the FULL-match total-goals line, not half-time variants', () => {
  const ou = extractOu25(matchGame.markets);
  // Full-match 2.5 line in the fixture is 1.87 / 1.87; the half-time markets
  // (category contains 5, subcategory 26/27) must be excluded.
  assert.deepEqual(ou, { over: 1.87, under: 1.87 });
});

test('normalizeMatch produces a schema-shaped match', () => {
  const m = normalizeMatch(matchGame, 'wm');
  assert.equal(m.id, 'wm-2026-07-14-fra-spa');
  assert.equal(m.home, 'Frankreich');
  assert.equal(m.away, 'Spanien');
  assert.equal(m.kickoff, '2026-07-14T19:00:00Z');
  assert.equal(m.venue, null);
  assert.deepEqual(m.odds1x2, { 1: 2.3, X: 3.25, 2: 3.31 });
  assert.deepEqual(m.ou25, { over: 1.87, under: 1.87 });
});

test('extract1x2 ignores handicap markets (which also carry 1/X/2 tips)', () => {
  // The Bundesliga fixture contains a "Handicap 0:1" market with 1/X/2 tips
  // right next to the real primary 1X2. The favourite must come out at ~1.27.
  const odds = extract1x2(blGame.markets);
  assert.deepEqual(odds, { 1: 1.27, X: 6.7, 2: 6.98 });
});

test('extractOu25 handles the German comma line encoded in the text (empty placeholders)', () => {
  // Bundesliga full-match line is "Over + / Under - 2,5" with placeholders:[]
  // and must be picked over the half-time / team-specific / double-chance decoys.
  const ou = extractOu25(blGame.markets);
  assert.deepEqual(ou, { over: 1.22, under: 3.83 });
});

test('normalizeMatch skips games whose team names did not resolve', () => {
  const broken = structuredClone(matchGame);
  broken.teams[0].name = 1099511857654; // numeric translation id
  assert.equal(normalizeMatch(broken, 'wm'), null);
});

test('normalizeOutrights maps each winner game and sorts by odds', () => {
  const outs = normalizeOutrights(outrightData.games);
  assert.ok(outs.length >= 4);
  // Sorted ascending (favourites first).
  for (let i = 1; i < outs.length; i++) assert.ok(outs[i].odds >= outs[i - 1].odds);
  const fra = outs.find((o) => o.team === 'Frankreich');
  assert.ok(fra && fra.odds > 1);
});

test('selectUpcoming sorts by kickoff and caps to max', () => {
  const now = Date.parse('2026-07-13T00:00:00Z');
  const mk = (iso) => ({ kickoff: iso });
  const list = [mk('2026-07-20T10:00:00Z'), mk('2026-07-14T10:00:00Z'), mk('2026-07-16T10:00:00Z')];
  const picked = selectUpcoming(list, 2, now);
  assert.equal(picked.length, 2);
  assert.equal(picked[0].kickoff, '2026-07-14T10:00:00Z');
  assert.equal(picked[1].kickoff, '2026-07-16T10:00:00Z');
});

test('validateDocument accepts a well-formed document and rejects a broken one', () => {
  const good = {
    source: 'merkurbets.de (Cashpoint)',
    fetchedAt: '2026-07-13T10:00:00Z',
    stale: false,
    competitions: [
      {
        id: 'wm',
        name: 'FIFA WM 2026',
        matches: [cleanMatch(normalizeMatch(matchGame, 'wm'))],
        outrights: [{ team: 'Frankreich', odds: 2.5 }],
      },
    ],
  };
  assert.equal(validateDocument(good).valid, true);

  const bad = structuredClone(good);
  bad.competitions[0].matches[0].odds1x2 = { 1: 'x', X: 2, 2: 3 };
  const res = validateDocument(bad);
  assert.equal(res.valid, false);
  assert.ok(res.errors.some((e) => e.includes('odds1x2')));
});
