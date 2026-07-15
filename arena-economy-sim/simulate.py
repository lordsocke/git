#!/usr/bin/env python3
"""ARENA — Monte-Carlo-Ökonomie-Simulation (Konzept-Gate A7).

Verwendet die exakten Formeln aus dem App-Code (siehe PARAMS.md). Simuliert
mehrere Spieler-Personas über 90 Tage, trennt Faucets (Coin-Zufluss) von Sinks
(Coin-Abfluss über den Liga-Hold), misst die Faucet/Sink-Bilanz und leitet
Launch-Balancing-Werte ab.

Design-Ziel (Konzept Kap. 6.2): Tages-Faucet ≈ 1,05–1,15 × Tages-Burn des
engagierten Non-Payers. Ausgabe: aktueller Zustand + empfohlene Skalierung.

Nur Standardbibliothek. Aufruf: python3 simulate.py
"""
from __future__ import annotations
import random
import statistics
from dataclasses import dataclass, field

# ----------------------------------------------------------------------------
# Exakte Modell-Parameter (aus GameState.swift / VirtualLeague.swift)
# ----------------------------------------------------------------------------
WELCOME = 1_000_000
LIGA_HOLD = 0.075          # V_PAYOUT 0.925
REAL_HOLD = 0.06           # ~5–8 %, spieltagsgebunden
WHEEL_COIN_EV_MULT = 5.0   # EV der Coin-Segmente × bonusAmount
WHEEL_SPINS_EV = 1.79      # Ø Freispiele je Rad-Dreh
FREE_SPINS_PER_CLAIM = 2
LEVELUP_SPINS = 3
MIN_STAKE = 5_000
STAKE_CAP = 10_000_000

CHALLENGE_COINS = {"bets": 60_000, "virt": 40_000, "bonus": 50_000, "spins": 40_000}
CHALLENGE_SPINS = 1
CHEST_COINS = 150_000
CHEST_SPINS = 2
TIPP_BASE = 25_000         # × min(streak,10), dann scaled()

# Minigame-Auszahlung analytisch (weights/pay3/pay2 aus SlotMath)
_W = [27, 23, 20, 14, 10, 6]
_PSUM = sum(_W)
_P = [w / _PSUM for w in _W]
_PAY3 = {0: 5, 1: 8, 2: 12, 3: 18, 4: 30, 5: 60}
_PAY2 = {3: 2, 4: 4, 5: 8}

def _minigame_ev_mult() -> float:
    """Erwarteter Auszahlungs-Multiplikator pro Freispiel (× Einsatzbasis)."""
    m3 = sum(_P[i] ** 3 * _PAY3[i] for i in _PAY3)                 # 3-of-a-kind
    m2 = sum(_P[i] ** 2 * (1 - _P[i]) * _PAY2[i] for i in _PAY2)   # 2-of-a-kind
    return m3 + m2

MINIGAME_EV = _minigame_ev_mult()   # ≈ 0.4809

# ----------------------------------------------------------------------------
# Formeln
# ----------------------------------------------------------------------------
@dataclass
class Config:
    """Ökonomie-Stellschrauben. IST = App-Code; RECOMMENDED = strukturelle Fixes."""
    name: str = "IST (Demo)"
    faucet_scale: float = 1.0        # globaler Faucet-Multiplikator
    bonus_growth: float = 1.10       # Faucet-Wachstum je Level
    growth_cap: int = 60             # Level, ab dem das Wachstum deckelt
    wheel_ev: float = 5.0            # Coin-EV des Bonus-Rads (× bonusAmount)
    xp_turnover_frac: float = 1.0    # Anteil des Einsatzes, der als XP zählt (steuert Leveling-Tempo)
    bonus_start: float = 20_000      # Bonus-Basis auf Level 1

def bonus_base(level: int, cfg: Config) -> float:
    return cfg.bonus_start * cfg.bonus_growth ** (min(level, cfg.growth_cap) - 1)

def scaled(base: float, level: int, cfg: Config) -> float:
    return base * cfg.bonus_growth ** (min(level, cfg.growth_cap) - 1)

def spin_stake_base(level: int, cfg: Config) -> float:
    return max(10_000, 0.5 * bonus_base(level, cfg))

def max_stake(level: int) -> int:
    band = (level - 1) // 2
    raw = 25_000 * 1.25 ** band
    return min(int(raw / 5_000) * 5_000, STAKE_CAP)

def xp_needed(level: int) -> float:
    return round(20_000 * level ** 1.35)

def streak_mult(streak: int) -> float:
    return 1 + 0.07 * min(streak, 7)

def stadium_mult(stadium_levels: int) -> float:
    return 1 + 0.015 * stadium_levels

def bonus_total_mult(streak: int, stadium_levels: int) -> float:
    return min(streak_mult(streak) * stadium_mult(stadium_levels), 2.0)

def stadium_stage_cost(stage: int) -> int:   # stage 0..4 innerhalb eines Ausbaus
    return 250_000 * 2 ** stage

# ----------------------------------------------------------------------------
# Persona
# ----------------------------------------------------------------------------
@dataclass
class Persona:
    name: str
    liga_tips: int            # Liga-Tipps pro Tag
    bonus_claims: int         # Bonus-Claims pro Tag (max 8 möglich)
    challenge_done: float     # Anteil der 4 Challenges + Chest, der geschafft wird (0..1)
    tages_tipp: float         # Wahrscheinlichkeit, den Tages-Tipp zu setzen
    uses_free_spins: bool     # spielt die verdienten Freispiele
    real_bets_matchday: int   # Realsport-Wetten an Spieltagen
    bet_fraction: float       # Einsatz je Wette als Anteil des Level-Max
    iap_coins_day: float = 0  # täglicher IAP-Zufluss (nur Payer)

PERSONAS = [
    Persona("Engagierter Non-Payer", liga_tips=20, bonus_claims=4, challenge_done=1.0,
            tages_tipp=1.0, uses_free_spins=True, real_bets_matchday=3, bet_fraction=0.40),
    Persona("Casual", liga_tips=5, bonus_claims=2, challenge_done=0.5,
            tages_tipp=0.5, uses_free_spins=True, real_bets_matchday=1, bet_fraction=0.30),
    Persona("Liga-Junkie (Vielspieler)", liga_tips=40, bonus_claims=5, challenge_done=1.0,
            tages_tipp=1.0, uses_free_spins=True, real_bets_matchday=2, bet_fraction=0.55),
    Persona("Whale (Payer)", liga_tips=30, bonus_claims=5, challenge_done=1.0,
            tages_tipp=1.0, uses_free_spins=True, real_bets_matchday=4, bet_fraction=0.90,
            iap_coins_day=1_500_000),
]

# ----------------------------------------------------------------------------
# Simulation
# ----------------------------------------------------------------------------
@dataclass
class DayAgg:
    faucet: float = 0.0
    burn: float = 0.0
    faucet_bonus: float = 0.0
    faucet_wheel: float = 0.0
    faucet_spins: float = 0.0
    faucet_challenges: float = 0.0
    faucet_tipp: float = 0.0
    faucet_levelup: float = 0.0
    faucet_iap: float = 0.0

def place_bet(rng, balance, stake, hold):
    """Eine Wette: Rückgabe (delta_balance, turnover). EV = -hold×stake, mit Varianz."""
    stake = min(stake, balance)
    if stake < MIN_STAKE:
        return 0.0, 0.0
    # impliziter Favoriten-/Streubereich: p aus 0.30..0.60 (Quote = (1-hold)/p)
    p = rng.uniform(0.30, 0.60)
    odds = (1 - hold) / p
    if rng.random() < p:
        delta = stake * odds - stake   # Gewinn
    else:
        delta = -stake                 # Verlust
    return delta, stake

def simulate_player(persona: Persona, days: int, cfg: Config, rng: random.Random):
    faucet_scale = cfg.faucet_scale
    coins = float(WELCOME)
    xp = 0.0
    level = 1
    streak = 1
    stadium_levels = 0          # 0..20 (4 Ausbauten × 5)
    stadium_stage = [0, 0, 0, 0]
    rescue_events = 0
    daily = []

    def level_from_xp(x):
        lvl, rest = 1, x
        while rest >= xp_needed(lvl) and lvl < 200:
            rest -= xp_needed(lvl); lvl += 1
        return lvl

    for day in range(days):
        agg = DayAgg()
        streak = min(streak + 1, 7)   # täglich aktiv → Serie wächst bis 7

        # --- FAUCET: Bonus-Claims ---
        claims = persona.bonus_claims
        free_spins = 0
        for c in range(claims):
            amt = bonus_base(level, cfg) * bonus_total_mult(streak, stadium_levels) * faucet_scale
            coins += amt; agg.faucet_bonus += amt
            free_spins += FREE_SPINS_PER_CLAIM
            if (c + 1) % 3 == 0:   # jeder 3. Claim → Rad
                wheel = amt * cfg.wheel_ev
                coins += wheel; agg.faucet_wheel += wheel
                free_spins += WHEEL_SPINS_EV

        # --- FAUCET: Daily Challenges + Chest ---
        done = persona.challenge_done
        ch = sum(CHALLENGE_COINS.values()) * done
        ch_scaled = scaled(ch, level, cfg) * faucet_scale
        coins += ch_scaled; agg.faucet_challenges += ch_scaled
        free_spins += CHALLENGE_SPINS * 4 * done
        if done >= 0.999:
            chest = scaled(CHEST_COINS, level, cfg) * faucet_scale
            coins += chest; agg.faucet_challenges += chest
            free_spins += CHEST_SPINS

        # --- FAUCET: Tages-Tipp ---
        if rng.random() < persona.tages_tipp:
            # Trefferwahrscheinlichkeit ~ Favoritentipp
            if rng.random() < 0.45:
                reward = scaled(TIPP_BASE * min(streak, 10), level, cfg) * faucet_scale
                coins += reward; agg.faucet_tipp += reward

        # --- FAUCET: Freispiele → Minigame (reiner Zufluss) ---
        if persona.uses_free_spins and free_spins > 0:
            win = free_spins * MINIGAME_EV * spin_stake_base(level, cfg)
            coins += win; agg.faucet_spins += win

        # --- FAUCET: IAP (Payer) ---
        if persona.iap_coins_day:
            coins += persona.iap_coins_day; agg.faucet_iap += persona.iap_coins_day

        # --- SINK: ARENA Liga ---
        stake = max(MIN_STAKE, min(int(persona.bet_fraction * max_stake(level) / 5000) * 5000, max_stake(level)))
        for _ in range(persona.liga_tips):
            if coins < MIN_STAKE:
                # Rettungsleine
                coins += 3 * MIN_STAKE; rescue_events += 1
            delta, turnover = place_bet(rng, coins, stake, LIGA_HOLD)
            coins += delta
            agg.burn += turnover * LIGA_HOLD
            xp += stake * cfg.xp_turnover_frac   # XP ~ Einsatz (Liga-Mult 1.0), Gewinnanteil vereinfacht

        # --- SINK: Realsport (nur ~jeden 2. Tag Spieltag) ---
        if day % 2 == 0:
            for _ in range(persona.real_bets_matchday):
                delta, turnover = place_bet(rng, coins, stake, REAL_HOLD)
                coins += delta
                agg.burn += turnover * REAL_HOLD
                xp += stake * 1.2 * cfg.xp_turnover_frac

        # --- SINK: Stadion (opportunistisch, wenn reichlich Balance) ---
        # Baut die jeweils günstigste nächste Stufe, solange Balance > 5× Kosten.
        for _ in range(3):
            cheapest = min((i for i in range(4) if stadium_stage[i] < 5),
                           key=lambda i: stadium_stage_cost(stadium_stage[i]), default=None)
            if cheapest is None:
                break
            cost = stadium_stage_cost(stadium_stage[cheapest])
            if coins > cost * 5:
                coins -= cost
                stadium_stage[cheapest] += 1
                stadium_levels += 1
            else:
                break

        # --- Level-up-Boni ---
        new_level = level_from_xp(xp)
        while level < new_level:
            level += 1
            lu = 30_000 * 1.08 ** min(level, cfg.growth_cap) * faucet_scale
            coins += lu; agg.faucet_levelup += lu

        agg.faucet = (agg.faucet_bonus + agg.faucet_wheel + agg.faucet_spins +
                      agg.faucet_challenges + agg.faucet_tipp + agg.faucet_levelup + agg.faucet_iap)
        daily.append((agg, coins, level))

    return daily, rescue_events

def run(persona: Persona, cfg: Config, days=90, trials=200, seed=42):
    rng = random.Random(seed + hash(persona.name) % 1000)
    end_balances, levels, rescues = [], [], []
    # Mittelwerte der Faucet-Komponenten und des Burns (aus dem letzten Drittel = eingeschwungen)
    tail_faucet = {k: [] for k in ("bonus", "wheel", "spins", "challenges", "tipp", "levelup", "iap", "total", "burn")}
    for t in range(trials):
        daily, resc = simulate_player(persona, days, cfg, rng)
        end_balances.append(daily[-1][1]); levels.append(daily[-1][2]); rescues.append(resc)
        for agg, _, _ in daily[days * 2 // 3:]:
            tail_faucet["bonus"].append(agg.faucet_bonus)
            tail_faucet["wheel"].append(agg.faucet_wheel)
            tail_faucet["spins"].append(agg.faucet_spins)
            tail_faucet["challenges"].append(agg.faucet_challenges)
            tail_faucet["tipp"].append(agg.faucet_tipp)
            tail_faucet["levelup"].append(agg.faucet_levelup)
            tail_faucet["iap"].append(agg.faucet_iap)
            tail_faucet["total"].append(agg.faucet)
            tail_faucet["burn"].append(agg.burn)
    mean = lambda xs: statistics.mean(xs) if xs else 0.0
    return {
        "faucet": {k: mean(v) for k, v in tail_faucet.items()},
        "end_median": statistics.median(end_balances),
        "end_p10": sorted(end_balances)[len(end_balances)//10],
        "end_p90": sorted(end_balances)[len(end_balances)*9//10],
        "level_median": statistics.median(levels),
        "rescue_mean": mean(rescues),
    }

def fmt(n):
    n = round(n)
    if abs(n) >= 1_000_000: return f"{n/1_000_000:.2f} Mio"
    if abs(n) >= 1_000: return f"{n/1_000:.0f} T"
    return str(n)

IST = Config(name="IST (Demo)")
# RECOMMENDED: strukturelle Fixes statt reinem Faucet-Regler:
#  - flacheres Faucet-Wachstum (+4 %/Level statt +10 %) mit früherem Cap (L40)
#  - Bonus-Rad-EV von 5× auf 3× (größter Einzel-Faucet)
#  - Leveling verlangsamt: nur 12 % des Turnovers zählen als XP (Konzept: „L50 nach ~2–3 Monaten")
#  - globaler Faucet-Feinregler 0.55
RECO = Config(name="EMPFEHLUNG v1", faucet_scale=0.55, bonus_growth=1.04,
              growth_cap=40, wheel_ev=3.0, xp_turnover_frac=0.12)

def persona_table(cfg: Config, title: str):
    print("=" * 96)
    print(f"{title}  [{cfg.name}: growth={cfg.bonus_growth}, cap L{cfg.growth_cap}, "
          f"radEV={cfg.wheel_ev}, xp={cfg.xp_turnover_frac}, scale={cfg.faucet_scale}]")
    print("=" * 96)
    print(f"{'Persona':26} {'Faucet/Tag':>12} {'Burn/Tag':>11} {'Ratio':>7} "
          f"{'Bal.d90 Median':>16} {'Bal.d90 p90':>14} {'Lvl':>4} {'Rettung':>8}")
    print("-" * 96)
    for p in PERSONAS:
        r = run(p, cfg)
        f, b = r["faucet"]["total"], r["faucet"]["burn"]
        ratio = f / b if b else float("inf")
        print(f"{p.name:26} {fmt(f):>12} {fmt(b):>11} {ratio:>6.1f}x "
              f"{fmt(r['end_median']):>16} {fmt(r['end_p90']):>14} {r['level_median']:>4.0f} {r['rescue_mean']:>8.1f}")
    print()

def composition(cfg: Config):
    p0 = PERSONAS[0]
    comp = run(p0, cfg)["faucet"]
    print(f"Faucet-Zusammensetzung — {p0.name} — {cfg.name} (Ø/Tag):")
    for k, lbl in [("bonus","Arena Bonus"),("wheel","Bonus-Rad"),("spins","Freispiele→Minigame"),
                   ("challenges","Challenges+Chest"),("tipp","Tages-Tipp"),("levelup","Level-ups")]:
        share = comp[k] / comp["total"] * 100 if comp["total"] else 0
        print(f"   {lbl:22} {fmt(comp[k]):>12}  ({share:4.1f}%)")
    print(f"   {'Burn (Liga+Real)':22} {fmt(comp['burn']):>12}")
    print(f"   → Faucet/Burn = {comp['total']/comp['burn']:.2f}x  (Ziel 1,05–1,15x)\n")

def main():
    print(f"Minigame-EV pro Freispiel: {MINIGAME_EV:.4f} × Einsatzbasis")
    print("(Start-Guthaben 1 Mio; Werte = Ø letztes Drittel von 90 Tagen, 200 Trials)\n")
    persona_table(IST, "IST-ZUSTAND")
    composition(IST)
    persona_table(RECO, "MIT EMPFEHLUNG v1")
    composition(RECO)
    print("Fazit: siehe REPORT.md")

if __name__ == "__main__":
    main()
