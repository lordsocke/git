// FALLBACK endpoint-discovery tool (Playwright). The service itself does NOT
// need this — it talks to the Cashpoint odds service directly over HTTPS (see
// DISCOVERY.md). Use this only if the direct endpoints change and you need to
// re-derive them from the live site's network traffic.
//
// Requires Playwright (an optional dependency):
//   npm install playwright
//   npx playwright install chromium
//   node tools/discover.mjs
//
// It loads merkurbets.de + the embedded sportsbook host, records every
// XHR/fetch to *.cashpoint.solutions / *.themill.tech, and writes:
//   tools/discovery-out/_index.json      (summary of endpoints + payloads)
//   tools/discovery-out/<n>_<url>.txt     (full response bodies)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, 'discovery-out');

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('Playwright is not installed. Run: npm install playwright && npx playwright install chromium');
  process.exit(1);
}

fs.mkdirSync(OUT, { recursive: true });
const records = [];
let idx = 0;

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ locale: 'de-DE', timezoneId: 'Europe/Berlin', viewport: { width: 1366, height: 900 } });
const page = await ctx.newPage();

const interesting = (u) => /cashpoint\.solutions|themill\.tech/.test(u);

page.on('response', async (resp) => {
  try {
    const req = resp.request();
    const url = resp.url();
    const rt = req.resourceType();
    if (!interesting(url) || ['image', 'font', 'stylesheet', 'media'].includes(rt)) return;
    const ct = resp.headers()['content-type'] || '';
    if (!(ct.includes('json') || rt === 'xhr' || rt === 'fetch')) return;
    let body = null;
    try { body = await resp.text(); } catch {}
    idx++;
    records.push({
      n: idx, method: req.method(), url, status: resp.status(),
      requestHeaders: req.headers(), postData: req.postData() || null,
      bodyLen: body ? body.length : 0, bodyHead: body ? body.slice(0, 1200) : null,
    });
    if (body && body.length < 5_000_000) {
      const safe = String(idx).padStart(3, '0') + '_' + req.method() + '_' +
        url.replace(/^https?:\/\//, '').replace(/[^a-zA-Z0-9]+/g, '_').slice(0, 90);
      fs.writeFileSync(path.join(OUT, `${safe}.txt`),
        `URL: ${url}\nMETHOD: ${req.method()}\nSTATUS: ${resp.status()}\nCT: ${ct}\nPOST: ${req.postData() || ''}\n\n${body}`);
    }
  } catch {}
});

async function visit(url, waitMs) {
  try {
    console.log('visit', url);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(waitMs);
  } catch (e) { console.warn('  nav failed:', e.message); }
}

await visit('https://www.merkurbets.de/', 6000);
await visit('https://www.merkurbets.de/sports', 8000);
await visit('https://v3-msw-mb-de.cashpoint.solutions/', 9000);

fs.writeFileSync(path.join(OUT, '_index.json'), JSON.stringify({ count: records.length, records }, null, 2));
await browser.close();

// Print a compact endpoint summary.
const seen = new Map();
for (const r of records) {
  const u = new URL(r.url);
  const key = `${r.method} ${u.origin}${u.pathname}`;
  const e = seen.get(key) || { key, count: 0, sample: r.postData };
  e.count++;
  seen.set(key, e);
}
console.log(`\nCaptured ${records.length} responses. Distinct endpoints:`);
for (const e of [...seen.values()].sort((a, b) => b.count - a.count)) {
  console.log(`  x${e.count}  ${e.key}${e.sample ? `\n         payload: ${e.sample.slice(0, 160)}` : ''}`);
}
console.log(`\nFull bodies + headers in: ${OUT}`);
