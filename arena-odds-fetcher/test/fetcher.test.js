// Regressionstests für die Review-Findings der Umstellung auf die offizielle
// Oddsservice-API (15.07.2026): Leere-Antwort-Guard und Container-Fallback.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchOddsDocument, TotalFetchError } from '../src/fetcher.js';

const CONFIG = { cp: { jurisdictionId: 10 } };

const GAME = {
  id: 1,
  startTime: new Date(Date.now() + 86400_000).toISOString(),
  teams: [
    { order: 0, name: 'Heim FC' },
    { order: 1, name: 'Gast SV' },
  ],
  markets: [
    {
      id: 22242,
      text: 'Wer gewinnt das Spiel',
      isPrimary: true,
      tips: [
        { text: '1', odds: 210 },
        { text: 'X', odds: 330 },
        { text: '2', odds: 320 },
      ],
    },
  ],
};

function stubClient({ onGetGames }) {
  return {
    getFilters: async () => ({ leagues: [] }), // leer → Fallback-IDs greifen
    getGames: onGetGames,
  };
}

test('leere Antworten überall → TotalFetchError statt leerem "Erfolgs"-Dokument', async () => {
  const client = stubClient({ onGetGames: async () => ({ games: [] }) });
  await assert.rejects(() => fetchOddsDocument(client, CONFIG), TotalFetchError);
});

test('Roh-Spiele vorhanden, aber Normalisierung verwirft alle (numerische Namen) → TotalFetchError', async () => {
  const numericNameGame = { ...GAME, teams: [{ order: 0, name: 1099511629546 }, { order: 1, name: 1099512000959 }] };
  const client = stubClient({ onGetGames: async () => ({ games: [numericNameGame] }) });
  await assert.rejects(() => fetchOddsDocument(client, CONFIG), /Normalisierung|verworfen/);
});

test('Container-Request wirft → Liga-Fallback liefert trotzdem Spiele', async () => {
  const calls = [];
  const client = stubClient({
    onGetGames: async (selector) => {
      calls.push(selector);
      if (selector.containerIds) throw new Error('container 500');
      return { games: [GAME] }; // Liga-Pfad funktioniert
    },
  });
  const doc = await fetchOddsDocument(client, CONFIG);
  const wm = doc.competitions.find((c) => c.id === 'wm');
  assert.ok(calls.some((s) => s.containerIds), 'Container wurde versucht');
  assert.ok(calls.some((s) => s.leagueIds), 'Liga-Fallback wurde versucht');
  assert.equal(wm.matches.length, 1);
  assert.equal(wm.matches[0].home, 'Heim FC');
  assert.equal(doc.stale, false);
});

test('ein leerer Wettbewerb neben gefüllten bleibt zulässig (kein globaler Fehler)', async () => {
  const client = stubClient({
    onGetGames: async (selector) => {
      // WM komplett leer: Container UND Fallback-Liga 33435 (Turnier vorbei).
      if (selector.containerIds) return { games: [] };
      if ((selector.leagueIds || []).includes(33435)) return { games: [] };
      return { games: [GAME] };
    },
  });
  const doc = await fetchOddsDocument(client, CONFIG);
  assert.equal(doc.competitions.find((c) => c.id === 'wm').matches.length, 0);
  assert.ok(doc.competitions.find((c) => c.id === 'bl').matches.length > 0);
});
