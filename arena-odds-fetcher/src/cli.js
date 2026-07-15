// One-off fetch to stdout (and snapshot). Useful for manual transfer when the
// server cannot be reached from outside, and for quick smoke tests:
//   node src/cli.js            -> pretty document to stdout + writes snapshot
//   node src/cli.js --validate -> also runs schema validation, exits non-zero on error
import { buildConfig } from './env.js';
import { setLogLevel, log } from './logger.js';
import { CashpointClient } from './cashpointClient.js';
import { OddsStore } from './store.js';
import { fetchOddsDocument } from './fetcher.js';
import { validateDocument } from './validate.js';

const config = buildConfig();
setLogLevel(process.env.LOG_LEVEL || 'info');

const doValidate = process.argv.includes('--validate');
const quiet = process.argv.includes('--quiet');

try {
  const client = new CashpointClient(config);
  const store = new OddsStore(config);
  const doc = await fetchOddsDocument(client, config);
  await store.writeSnapshot(doc);

  if (doValidate) {
    const { valid, errors } = validateDocument(doc);
    if (!valid) {
      log.error(`schema INVALID (${errors.length} problems)`);
      for (const e of errors.slice(0, 40)) log.error('  ' + e);
      process.exit(1);
    }
    log.info('schema valid');
  }

  if (!quiet) process.stdout.write(JSON.stringify(doc, null, 2) + '\n');
  const matchCount = doc.competitions.reduce((n, c) => n + c.matches.length, 0);
  log.info(`done — ${doc.competitions.length} competitions, ${matchCount} matches, snapshot at ${config.snapshotPath}`);
} catch (err) {
  log.error('fetch failed', err.stack || err.message);
  process.exit(2);
}
