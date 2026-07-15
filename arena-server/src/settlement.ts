import { pool, withTx } from "./db.js";
import { postManyIn } from "./wallet.js";

// ---------------------------------------------------------------------------
// Settlement-Engine (B3): Ergebnis → Legs → Bets → Auszahlung.
// Jede Stufe ist idempotent:
//   * Match: nur 'scheduled' → 'finished'/'void'; gleiches Ergebnis erneut = No-Op.
//   * Legs: werden nur aus 'open' heraus entschieden.
//   * Bets: FOR UPDATE + nur aus 'open'; Auszahlung mit deterministischem
//     Ledger-Key `bet:<id>:payout` – ein Doppel-Credit ist damit unmöglich.
// Der Sweep ist beliebig oft wiederholbar (Crash-Recovery: einfach erneut aufrufen).
// Heute füttert ein Admin-Endpunkt diese Engine; der echte Ergebnis-Feed (B4)
// ruft später exakt dieselben Funktionen auf.
// ---------------------------------------------------------------------------

/** Ergebnis-Konflikt (anderes Ergebnis für bereits abgerechnetes Spiel) → HTTP 409. */
export class ResultConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ResultConflictError";
  }
}

export class MatchNotFoundError extends Error {
  constructor(matchId: string) {
    super(`Unbekanntes Spiel: ${matchId}`);
    this.name = "MatchNotFoundError";
  }
}

/** Gewinner-Pick je Markt aus dem Endstand ableiten. */
function winningPicks(home: number, away: number): Record<string, string> {
  return {
    "1X2": home > away ? "1" : home < away ? "2" : "X",
    OU25: home + away >= 3 ? "over" : "under",
  };
}

export interface SettleSummary {
  matchId: string;
  alreadyFinished: boolean;
  legsSettled: number;
  betsSettled: number;
}

/**
 * Endergebnis verbuchen und alle betroffenen Wetten abrechnen.
 * Wiederholter Aufruf mit demselben Ergebnis ist ein sicherer No-Op (plus Sweep –
 * das macht ihn zugleich zum Recovery-Mechanismus nach einem Crash).
 */
export async function recordResult(matchId: string, home: number, away: number): Promise<SettleSummary> {
  if (!Number.isInteger(home) || !Number.isInteger(away) || home < 0 || away < 0 || home > 99 || away > 99) {
    throw new ResultConflictError("Ergebnis muss aus ganzen Zahlen 0–99 bestehen");
  }

  const { alreadyFinished, legsSettled } = await withTx(async (c) => {
    const upd = await c.query(
      `update matches set status = 'finished', result_home = $2, result_away = $3, settled_at = now()
       where id = $1 and status = 'scheduled' returning id`,
      [matchId, home, away],
    );

    let alreadyFinished = false;
    if (upd.rowCount === 0) {
      const { rows } = await c.query<{ status: string; result_home: number | null; result_away: number | null }>(
        "select status, result_home, result_away from matches where id = $1",
        [matchId],
      );
      const m = rows[0];
      if (!m) throw new MatchNotFoundError(matchId);
      if (m.status === "void") throw new ResultConflictError(`Spiel ${matchId} wurde annulliert`);
      if (m.result_home !== home || m.result_away !== away) {
        throw new ResultConflictError(
          `Spiel ${matchId} ist bereits mit ${m.result_home}:${m.result_away} abgerechnet`,
        );
      }
      alreadyFinished = true; // gleiches Ergebnis erneut → idempotent, Sweep läuft trotzdem
    }

    // Offene Legs dieses Spiels entscheiden (nur aus 'open' heraus → idempotent).
    const picks = winningPicks(home, away);
    const settled = await c.query(
      `update bet_legs set status = case
         when (market = '1X2'  and pick = $2) then 'won'
         when (market = 'OU25' and pick = $3) then 'won'
         else 'lost' end
       where match_id = $1 and status = 'open'`,
      [matchId, picks["1X2"], picks["OU25"]],
    );
    return { alreadyFinished, legsSettled: settled.rowCount ?? 0 };
  });

  const betsSettled = await sweepMatch(matchId);
  return { matchId, alreadyFinished, legsSettled, betsSettled };
}

/**
 * Spiel annullieren (Absage/Abbruch): alle offenen Legs werden 'void'
 * (Quote zählt als 1,0) – Einzelwetten werden damit vollständig erstattet.
 */
export async function voidMatch(matchId: string): Promise<SettleSummary> {
  const { alreadyFinished, legsSettled } = await withTx(async (c) => {
    const upd = await c.query(
      "update matches set status = 'void', settled_at = now() where id = $1 and status = 'scheduled' returning id",
      [matchId],
    );
    let alreadyFinished = false;
    if (upd.rowCount === 0) {
      const { rows } = await c.query<{ status: string }>("select status from matches where id = $1", [matchId]);
      const m = rows[0];
      if (!m) throw new MatchNotFoundError(matchId);
      if (m.status === "finished") throw new ResultConflictError(`Spiel ${matchId} ist bereits regulär abgerechnet`);
      alreadyFinished = true;
    }
    const settled = await c.query(
      "update bet_legs set status = 'void' where match_id = $1 and status = 'open'",
      [matchId],
    );
    return { alreadyFinished, legsSettled: settled.rowCount ?? 0 };
  });

  const betsSettled = await sweepMatch(matchId);
  return { matchId, alreadyFinished, legsSettled, betsSettled };
}

/**
 * Recovery-Sweep (Review-Finding): findet Wetten, die entscheidbar sind, aber
 * 'open' hängen – z. B. nach einem Crash zwischen Leg-Settlement und Bet-Sweep.
 * Entscheidbar heißt: kein offenes Leg mehr ODER mindestens ein verlorenes Leg.
 * Läuft beim Serverstart und periodisch; beliebig oft wiederholbar.
 */
export async function sweepUndecidedBets(): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    `select b.id from bets b
     where b.status = 'open'
       and ( not exists (select 1 from bet_legs l where l.bet_id = b.id and l.status = 'open')
             or exists  (select 1 from bet_legs l where l.bet_id = b.id and l.status = 'lost') )`,
  );
  let settled = 0;
  for (const r of rows) {
    if (await settleBetIfDecided(r.id)) settled++;
  }
  return settled;
}

/**
 * Verwaiste Spiele annullieren (Review-Finding): 'scheduled' lange nach Kickoff
 * heißt Absage/Verlegung oder fehlender Ergebnis-Eingang – Einsätze fließen
 * zurück, statt Wetten unbegrenzt offen zu halten.
 */
export async function voidStaleMatches(maxAgeHours: number): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    "select id from matches where status = 'scheduled' and kickoff < now() - make_interval(hours => $1)",
    [maxAgeHours],
  );
  for (const r of rows) {
    await voidMatch(r.id);
  }
  return rows.length;
}

/** Alle Wetten mit Legs auf diesem Spiel prüfen und – falls entschieden – abrechnen. */
export async function sweepMatch(matchId: string): Promise<number> {
  const { rows } = await pool.query<{ bet_id: string }>(
    "select distinct bet_id from bet_legs where match_id = $1",
    [matchId],
  );
  let settled = 0;
  for (const r of rows) {
    if (await settleBetIfDecided(r.bet_id)) settled++;
  }
  return settled;
}

/**
 * Eine Wette abrechnen, sobald alle Legs entschieden sind. Eigene Transaktion
 * pro Wette (Status-Update + Auszahlung atomar); Wiederholung ist wirkungslos.
 * @returns true, wenn diese Ausführung die Wette abgerechnet hat.
 */
export async function settleBetIfDecided(betId: string): Promise<boolean> {
  return withTx(async (c) => {
    const { rows: betRows } = await c.query<{ user_id: string; stake: number; status: string }>(
      "select user_id, stake, status from bets where id = $1 for update",
      [betId],
    );
    const bet = betRows[0];
    if (!bet || bet.status !== "open") return false;

    const { rows: legs } = await c.query<{ status: string; odds: string }>(
      "select status, odds from bet_legs where bet_id = $1",
      [betId],
    );

    let status: "won" | "lost" | "void";
    let payout = 0;
    if (legs.some((l) => l.status === "lost")) {
      // Ein verlorenes Leg entscheidet die Wette SOFORT – auch wenn andere Legs
      // noch offen sind (Review-Finding: sonst hängt die Kombi an einem Spiel,
      // das nie abgerechnet wird, obwohl sie längst verloren ist).
      status = "lost";
    } else if (legs.some((l) => l.status === "open")) {
      return false; // noch nicht entscheidbar
    } else if (legs.every((l) => l.status === "void")) {
      status = "void"; // komplette Erstattung
      payout = bet.stake;
    } else {
      status = "won"; // void-Legs zählen als Quote 1,0
      const odds = legs.filter((l) => l.status === "won").reduce((p, l) => p * Number(l.odds), 1);
      payout = Math.round(bet.stake * odds);
    }

    await c.query(
      "update bets set status = $2, payout = $3, settled_at = now() where id = $1",
      [betId, status, payout],
    );

    if (payout > 0) {
      await postManyIn(c, bet.user_id, [
        {
          amount: payout,
          reason: status === "void" ? "bet_void" : "bet_payout",
          idempotencyKey: `bet:${betId}:payout`,
          refType: "bet",
          refId: betId,
        },
      ]);
    }
    return true;
  });
}
