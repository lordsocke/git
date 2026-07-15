#!/usr/bin/env python3
"""Tuning-Modell für die 'Start klein → Millionär'-Progression (Start 1.000 Coins).

Eigenständig (nicht simulate.py), damit ich volle Kontrolle über die neuen Anker
habe. Kernentscheidungen:
  - Coins-Anker klein (Start 1.000), alle Beträge wachsen mit dem Level.
  - maxStake wächst SCHNELLER als die Faucets → Burn holt irgendwann auf →
    Balance klettert erst stark und plateaut dann in den (niedrigen) Millionen.
  - XP von Coins ENTKOPPELT: Leveln nach Aktivität (Anzahl Aktionen), nicht nach
    Einsatzhöhe. Sonst würde Leveln bei kleinen Coins nie vorankommen; behebt zudem
    das frühere Leveling-Runaway.
Ziel: 1.000 → ~1 Mio um Woche 4–8, danach Plateau niedrige Millionen; Heavy-User
unter Kaufdruck (Ratio ≤ 1). Reproduzieren: python3 tune_startsmall.py
"""
import random, statistics

# ---- Coin-Anker (Level 1) + Wachstum -------------------------------------
WELCOME      = 1_000
BONUS_L1     = 60           # Bonus-Basis auf L1
G_BONUS      = 1.11         # Faucet-Wachstum / Level (Bonus, Challenges, Tipp, Minigame-Basis)
CAP_BONUS    = 55
STAKE_L1     = 40           # maxStake auf L1
G_STAKE      = 1.165        # Einsatz-Wachstum / Level (schneller als Faucet ⇒ Plateau)
CAP_STAKE    = 55
MIN_STAKE    = 10
CH_L1        = {"bets":50, "virt":35, "bonus":45, "spins":35}
CHEST_L1     = 120
TIPP_L1      = 40           # × min(streak,10)
HOLD         = 0.075
WHEEL_EV     = 3.0
MINIGAME_EV  = 0.4809       # pro Freispiel × Einsatzbasis (0.5 × bonusBase)

# ---- XP: aktivitätsbasiert (Coin-entkoppelt) -----------------------------
XP_BET, XP_SPIN, XP_CLAIM, XP_TIPP, XP_CHSET = 1.0, 0.4, 1.2, 2.5, 3.0
def xp_needed(l):            # sub-linear: kalibriert auf L8 ~Tag3, L50 ~Tag75 (Engagierter)
    return 7.0 * l ** 0.76

def geo(l1, g, cap, level):
    return l1 * g ** (min(level, cap) - 1)

def bonus_base(level): return geo(BONUS_L1, G_BONUS, CAP_BONUS, level)
def scaled(base, level): return base * G_BONUS ** (min(level, CAP_BONUS) - 1)
def max_stake(level):
    raw = geo(STAKE_L1, G_STAKE, CAP_STAKE, level)
    return max(MIN_STAKE, int(raw / 10) * 10)
def spin_base(level): return max(10, 0.5 * bonus_base(level))

def streak_mult(s): return 1 + 0.07 * min(s, 7)
def bonus_mult(s, stad): return min(streak_mult(s) * (1 + 0.015 * stad), 2.0)

def level_from_xp(x):
    lvl, rest, need = 1, x, xp_needed(1)
    # xp_needed hier als "Kosten der Stufe l" interpretiert (Differenz):
    total = 0
    l = 1
    while l < 200:
        step = xp_needed(l)
        if x >= total + step:
            total += step; l += 1
        else:
            break
    return l

def simulate(persona, days=120, seed=1, trials=40):
    trajs, levels, ratios = [], [], []
    for t in range(trials):
        rng = random.Random(seed + t)
        coins, xp, level, streak, stad = float(WELCOME), 0.0, 1, 1, 0
        stad_stage = [0,0,0,0]
        bal = []
        f_tot = b_tot = 0.0
        for day in range(days):
            streak = min(streak + 1, 7)
            free = 0
            # Bonus
            for c in range(persona["claims"]):
                amt = bonus_base(level) * bonus_mult(streak, stad)
                coins += amt; f_tot += amt if day >= days*2//3 else 0
                free += 2
                if (c+1) % 3 == 0:
                    w = amt * WHEEL_EV; coins += w; f_tot += w if day >= days*2//3 else 0
                    free += 1.79
                xp += XP_CLAIM
            # Challenges
            done = persona["chdone"]
            ch = scaled(sum(CH_L1.values()) * done, level); coins += ch
            f_tot += ch if day >= days*2//3 else 0
            free += 4 * done
            if done >= 0.999:
                chest = scaled(CHEST_L1, level); coins += chest
                f_tot += chest if day >= days*2//3 else 0
                free += 2
                xp += XP_CHSET
            # Tages-Tipp
            if rng.random() < persona["tipp"]:
                xp += XP_TIPP
                if rng.random() < 0.45:
                    r = scaled(TIPP_L1 * min(streak,10), level); coins += r
                    f_tot += r if day >= days*2//3 else 0
            # Freispiele
            if free > 0:
                win = free * MINIGAME_EV * spin_base(level); coins += win
                f_tot += win if day >= days*2//3 else 0
                xp += free * XP_SPIN
            # IAP
            coins += persona.get("iap", 0)
            # Liga-Burn
            stake = max(MIN_STAKE, int(persona["betfrac"] * max_stake(level) / 10)*10)
            for _ in range(persona["tips"]):
                if coins < MIN_STAKE: coins += 3*MIN_STAKE
                s = min(stake, coins)
                if s < MIN_STAKE: continue
                p = rng.uniform(0.30, 0.60); odds = (1-HOLD)/p
                coins += (s*odds - s) if rng.random() < p else -s
                b_tot += s*HOLD if day >= days*2//3 else 0
                xp += XP_BET
            # Realsport (jeden 2. Tag)
            if day % 2 == 0:
                for _ in range(persona["real"]):
                    s = min(stake, coins)
                    if s < MIN_STAKE: continue
                    p = rng.uniform(0.30,0.60); odds=(1-HOLD)/p
                    coins += (s*odds - s) if rng.random() < p else -s
                    b_tot += s*HOLD if day >= days*2//3 else 0
                    xp += XP_BET
            # Stadion-Sink (skaliert mit Level ⇒ bleibt relevant)
            for _ in range(3):
                idx = min((i for i in range(4) if stad_stage[i] < 5),
                          key=lambda i: stad_stage[i], default=None)
                if idx is None: break
                cost = geo(2000, G_STAKE, CAP_STAKE, level) * (2 ** stad_stage[idx])
                if coins > cost * 6:
                    coins -= cost; stad_stage[idx] += 1; stad += 1
                else: break
            level = level_from_xp(xp)
            bal.append(coins)
        trajs.append(bal); levels.append(level)
        if b_tot > 0: ratios.append(f_tot / b_tot)
    med = [statistics.median(t[d] for t in trajs) for d in range(days)]
    return med, statistics.median(levels), (statistics.mean(ratios) if ratios else 0)

def fmt(n):
    n = round(n)
    if abs(n) >= 1_000_000: return f"{n/1_000_000:.2f} Mio"
    if abs(n) >= 1_000: return f"{n/1_000:.1f} T"
    return str(n)

PERSONAS = {
    "Engagierter Non-Payer": dict(claims=4, tips=20, chdone=1.0, tipp=1.0, real=3, betfrac=0.40),
    "Casual":                dict(claims=2, tips=5,  chdone=0.5, tipp=0.5, real=1, betfrac=0.30),
    "Liga-Junkie":           dict(claims=5, tips=40, chdone=1.0, tipp=1.0, real=2, betfrac=0.55),
    "Whale (Payer)":         dict(claims=5, tips=30, chdone=1.0, tipp=1.0, real=4, betfrac=0.90, iap=250),
}

def main():
    print(f"Start {fmt(WELCOME)} · Bonus L1 {BONUS_L1} (×{G_BONUS}/Lvl cap{CAP_BONUS}) · "
          f"maxStake L1 {STAKE_L1} (×{G_STAKE}/Lvl) · XP aktivitätsbasiert\n")
    print(f"{'Persona':24} {'Tag1':>7} {'Tag7':>8} {'Tag30':>9} {'Tag60':>9} {'Tag90':>9} "
          f"{'1Mio@Tag':>9} {'Lvl90':>6} {'Ratio':>6}")
    print("-"*92)
    p0 = None
    for name, per in PERSONAS.items():
        med, lvl, ratio = simulate(per)
        d1m = next((d+1 for d,v in enumerate(med) if v >= 1_000_000), None)
        print(f"{name:24} {fmt(med[0]):>7} {fmt(med[6]):>8} {fmt(med[29]):>9} {fmt(med[59]):>9} "
              f"{fmt(med[89]):>9} {str(d1m) if d1m else '>120':>9} {lvl:>6.0f} {ratio:>5.1f}x")
    # Level-Meilensteine des Zielsegments (Median über Trials: Tag, an dem Level erreicht)
    print("\nLevel-Pacing (Engagierter Non-Payer, Median-Tag bei Erreichen):")
    days = 120
    reach = {8: [], 20: [], 35: [], 50: []}
    for t in range(40):
        rng = random.Random(100 + t)
        coins, xp, level, streak, stad = float(WELCOME), 0.0, 1, 1, 0
        stad_stage = [0,0,0,0]; per = PERSONAS["Engagierter Non-Payer"]
        seen = {}
        for day in range(days):
            streak = min(streak + 1, 7); free = 0
            for c in range(per["claims"]):
                amt = bonus_base(level) * bonus_mult(streak, stad); coins += amt; free += 2
                if (c+1) % 3 == 0: coins += amt*WHEEL_EV; free += 1.79
                xp += XP_CLAIM
            ch = scaled(sum(CH_L1.values()), level); coins += ch; free += 4
            coins += scaled(CHEST_L1, level); free += 2; xp += XP_CHSET
            xp += XP_TIPP
            if free: coins += free*MINIGAME_EV*spin_base(level); xp += free*XP_SPIN
            stake = max(MIN_STAKE, int(per["betfrac"]*max_stake(level)/10)*10)
            xp += per["tips"] + (per["real"] if day%2==0 else 0)
            level = level_from_xp(xp)
            for m in reach:
                if level >= m and m not in seen: seen[m] = day+1
        for m in reach:
            if m in seen: reach[m].append(seen[m])
    for m in sorted(reach):
        vals = reach[m]
        print(f"   L{m:<2}: Tag {int(statistics.median(vals)) if vals else '>120'}")

if __name__ == "__main__":
    main()
