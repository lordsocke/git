// Tiny leveled logger writing structured-ish lines to stdout/stderr.
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

let threshold = LEVELS.info;

export function setLogLevel(level) {
  threshold = LEVELS[level] ?? LEVELS.info;
}

function emit(level, msg, extra) {
  if (LEVELS[level] < threshold) return;
  const ts = new Date().toISOString();
  const base = `${ts} [${level.toUpperCase()}] ${msg}`;
  const line = extra !== undefined ? `${base} ${safe(extra)}` : base;
  if (level === 'error' || level === 'warn') process.stderr.write(line + '\n');
  else process.stdout.write(line + '\n');
}

function safe(obj) {
  try {
    return typeof obj === 'string' ? obj : JSON.stringify(obj);
  } catch {
    return String(obj);
  }
}

export const log = {
  debug: (m, e) => emit('debug', m, e),
  info: (m, e) => emit('info', m, e),
  warn: (m, e) => emit('warn', m, e),
  error: (m, e) => emit('error', m, e),
};
