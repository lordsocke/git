// Lightweight structural validation of the target-schema document. No external
// schema library — just enough to catch contract regressions and to power a
// meaningful /health readiness signal.

export function validateDocument(doc) {
  const errors = [];
  const push = (p, msg) => errors.push(`${p}: ${msg}`);

  if (!doc || typeof doc !== 'object') {
    return { valid: false, errors: ['root: not an object'] };
  }
  if (typeof doc.source !== 'string') push('source', 'expected string');
  if (!isIsoDate(doc.fetchedAt)) push('fetchedAt', 'expected ISO-8601 timestamp');
  if (typeof doc.stale !== 'boolean') push('stale', 'expected boolean');
  if (!Array.isArray(doc.competitions)) {
    push('competitions', 'expected array');
    return { valid: errors.length === 0, errors };
  }

  doc.competitions.forEach((c, ci) => {
    const cp = `competitions[${ci}]`;
    if (typeof c.id !== 'string' || !c.id) push(cp + '.id', 'expected non-empty string');
    if (typeof c.name !== 'string') push(cp + '.name', 'expected string');
    if (!Array.isArray(c.matches)) push(cp + '.matches', 'expected array');
    if (!Array.isArray(c.outrights)) push(cp + '.outrights', 'expected array');

    (c.matches || []).forEach((m, mi) => {
      const mp = `${cp}.matches[${mi}]`;
      if (typeof m.id !== 'string' || !m.id) push(mp + '.id', 'expected non-empty string');
      if (typeof m.home !== 'string' || !m.home) push(mp + '.home', 'expected non-empty string');
      if (typeof m.away !== 'string' || !m.away) push(mp + '.away', 'expected non-empty string');
      if (m.kickoff != null && !isIsoDate(m.kickoff)) push(mp + '.kickoff', 'expected ISO date or null');
      if (!('venue' in m)) push(mp + '.venue', 'field missing');
      validateOdds1x2(m.odds1x2, mp + '.odds1x2', push);
      validateOu25(m.ou25, mp + '.ou25', push);
    });

    (c.outrights || []).forEach((o, oi) => {
      const op = `${cp}.outrights[${oi}]`;
      if (typeof o.team !== 'string' || !o.team) push(op + '.team', 'expected non-empty string');
      if (!isPosNumber(o.odds)) push(op + '.odds', 'expected positive number');
    });
  });

  return { valid: errors.length === 0, errors };
}

function validateOdds1x2(v, p, push) {
  if (v == null) return; // null allowed when market not offered
  if (typeof v !== 'object') return push(p, 'expected object or null');
  for (const k of ['1', 'X', '2']) {
    if (!isPosNumber(v[k])) push(`${p}.${k}`, 'expected positive number');
  }
}

function validateOu25(v, p, push) {
  if (v == null) return;
  if (typeof v !== 'object') return push(p, 'expected object or null');
  if (!isPosNumber(v.over)) push(p + '.over', 'expected positive number');
  if (!isPosNumber(v.under)) push(p + '.under', 'expected positive number');
}

function isPosNumber(n) {
  return typeof n === 'number' && Number.isFinite(n) && n > 0;
}

function isIsoDate(s) {
  if (typeof s !== 'string') return false;
  const t = Date.parse(s);
  return Number.isFinite(t);
}
