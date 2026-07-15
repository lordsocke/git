import SwiftUI

// MARK: - ARENA Liga: virtuelle Spiele im Minutentakt (Evergreen-Loop + Coin-Senke)

struct VTeam: Identifiable {
    let id: Int
    let name: String
    let strength: Double
    let color: Color

    var initials: String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined().prefix(2).uppercased()
    }
    var short: String { String(name.split(separator: " ").first ?? "") }
}

let VTEAMS: [VTeam] = [
    VTeam(id: 0, name: "Aurora FC", strength: 82, color: Theme.blue),
    VTeam(id: 1, name: "Union Kobalt", strength: 78, color: Theme.green),
    VTeam(id: 2, name: "SC Meridian", strength: 75, color: Theme.gold),
    VTeam(id: 3, name: "Athletico Nova", strength: 73, color: Theme.red),
    VTeam(id: 4, name: "FC Boreas", strength: 70, color: Color(red: 0.78, green: 0.49, blue: 1.0)),
    VTeam(id: 5, name: "Sparta Lyra", strength: 67, color: Color(red: 1.0, green: 0.54, blue: 0.36)),
    VTeam(id: 6, name: "Dynamo Quarz", strength: 64, color: Color(red: 0.49, green: 0.89, blue: 1.0)),
    VTeam(id: 7, name: "Real Zephyr", strength: 60, color: Theme.gold2),
]

enum VPhase: String {
    case pause   // Countdown zum Anstoß, Pre-Match-Wetten offen
    case live    // Spiel läuft, Live-Wetten offen (außer Suspension)
    case ft      // Schlusspfiff, Anzeige des Ergebnisses
}

struct VirtualMatch {
    var vid: Int
    var phase: VPhase = .pause
    var until: Date               // Phasenende (pause/ft)
    var home: Int
    var away: Int
    var min: Double = 0
    var gh: Int = 0
    var ga: Int = 0
    var q: Double                 // Heimanteil am Torprozess (= Preismodell-Parameter)
    var odds: [String: Double]
    var suspended: Bool = false
    var suspUntil: Date = .distantPast
    var events: [String] = []
}

let V_PAYOUT = 0.925              // Auszahlungsfaktor ⇒ Hold 7,5 % des Einsatzes (Overround 8,1 %)
let V_LAMBDA = 179.0 * 0.015      // Torfenster: 179 Halb-Minuten-Ticks à p = 0,015 ⇒ E[Tore] ≈ 2,685

private func r2(_ v: Double) -> Double {
    (min(max(v, 1.03), 29.0) * 100).rounded() / 100
}

/// Heimanteil q aus den Teamstärken (inkl. kleinem Heimvorteil).
func vHomeShare(home: Int, away: Int) -> Double {
    let sh = VTEAMS[home].strength, sa = VTEAMS[away].strength
    return min(max(0.53 + (sh - sa) * 0.01, 0.15), 0.85)
}

private func poissonArray(_ lam: Double, upTo n: Int) -> [Double] {
    var arr = [exp(-lam)]
    for k in 1...n { arr.append(arr[k - 1] * lam / Double(k)) }
    return arr
}

/// Kalibrier-Invariante: Quoten werden EXAKT aus dem Simulationsmodell abgeleitet
/// (Tore ~ Poisson(λ·Restzeit), Heimanteil q, Splitting über Endstände).
/// Damit ist der EV je Markt konstruktionsbedingt = V_PAYOUT − 1 = −7,5 %
/// (modulo Quotenrundung/-clamps) — Preisheuristiken sind verboten.
func vOdds(q: Double, gh: Int, ga: Int, t: Double) -> [String: Double] {
    let lam = V_LAMBDA * (1 - t)
    let n = 12
    let ph = poissonArray(lam * q, upTo: n)
    let pa = poissonArray(lam * (1 - q), upTo: n)
    var p1 = 0.0, px = 0.0, p2 = 0.0, pOver = 0.0
    for i in 0...n {
        for j in 0...n {
            let p = ph[i] * pa[j]
            let h = gh + i, a = ga + j
            if h > a { p1 += p } else if h < a { p2 += p } else { px += p }
            if h + a > 2 { pOver += p }
        }
    }
    var odds: [String: Double] = [
        "1X2|1": r2(V_PAYOUT / max(p1, 0.033)),
        "1X2|X": r2(V_PAYOUT / max(px, 0.033)),
        "1X2|2": r2(V_PAYOUT / max(p2, 0.033)),
    ]
    if pOver > 0.005 && pOver < 0.995 {
        odds["OU|Über 2,5"] = r2(V_PAYOUT / pOver)
        odds["OU|Unter 2,5"] = r2(V_PAYOUT / (1 - pOver))
    }
    return odds
}

func vLiveOdds(_ v: VirtualMatch) -> [String: Double] {
    vOdds(q: v.q, gh: v.gh, ga: v.ga, t: v.min / 90)
}

// MARK: - Tabelle

struct TeamRecord: Codable, Equatable {
    var points: Int = 0
    var played: Int = 0
}
