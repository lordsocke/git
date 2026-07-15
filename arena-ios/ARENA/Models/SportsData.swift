import Foundation

// MARK: - Echte Spiele (WM-2026-Halbfinale)
// Quotenquelle: Merkur Bets (vorgesehener Lieferant; Plattform: Cashpoint/Gauselmann,
// apiv3-msw-mb-de.cashpoint.solutions — im Produkt kommt der Feed hausintern von dort).
// Aktuell Markt-Snapshot vom 12.07.2026 (Opening Lines der Halbfinals, aus US-Moneylines
// umgerechnet), da die Merkur-Quoten nur in der App/SPA ausgeliefert werden.

struct MatchResult: Codable, Equatable {
    var out: String   // "1" | "X" | "2"
    var gh: Int
    var ga: Int
}

struct RealMatch: Identifiable {
    let id: String
    let home: String
    let away: String
    let flagHome: String
    let flagAway: String
    let when: String
    let odds1x2: [(String, Double)]   // geordnete Keys: "1","X","2"
    let ouOdds: [(String, Double)]    // "Über 2,5","Unter 2,5"

    func odd(market: String, pick: String) -> Double? {
        let src = market == "1X2" ? odds1x2 : ouOdds
        return src.first(where: { $0.0 == pick })?.1
    }
}

// MARK: - Wettbewerbe (Ligen/Pokale) — Slotomania-Muster: Start-Liga wählen,
// alle 10 Level einen weiteren Slot freischalten; Event-Turniere (WM) sind für
// alle offen. Bewusst kuratiert: wenige Spiele + wenige Märkte je Wettbewerb.

struct Competition: Identifiable {
    let id: String
    let name: String
    let icon: String        // Emoji-Logo
    let sub: String         // Kurzbeschreibung
    let isEvent: Bool       // Event-Turnier: immer offen, zählt nicht als Slot
    let matches: [RealMatch]
}

// DEFAULT_COMPETITIONS = Demo-Fallback (Snapshot). Zur Laufzeit ersetzt der
// OddsService diese durch echte Merkur-/Cashpoint-Quoten (GameState.competitions).
let DEFAULT_COMPETITIONS: [Competition] = [
    Competition(id: "wm", name: "WM 2026", icon: "🏆", sub: "Event · für alle offen", isEvent: true, matches: [
        RealMatch(id: "s1", home: "Frankreich", away: "Spanien", flagHome: "🇫🇷", flagAway: "🇪🇸",
                  when: "Di 21:00 · Dallas · Halbfinale",
                  odds1x2: [("1", 2.35), ("X", 3.20), ("2", 3.10)],
                  ouOdds: [("Über 2,5", 2.10), ("Unter 2,5", 1.72)]),
        RealMatch(id: "s2", home: "England", away: "Argentinien", flagHome: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", flagAway: "🇦🇷",
                  when: "Mi 21:00 · Atlanta · Halbfinale",
                  odds1x2: [("1", 2.65), ("X", 3.00), ("2", 2.90)],
                  ouOdds: [("Über 2,5", 2.20), ("Unter 2,5", 1.66)]),
    ]),
    Competition(id: "bl", name: "Bundesliga", icon: "🇩🇪", sub: "18 Teams · Sa/So", isEvent: false, matches: [
        RealMatch(id: "bl1", home: "FC Bayern", away: "RB Leipzig", flagHome: "🔴", flagAway: "⚪️",
                  when: "Sa 18:30 · Topspiel",
                  odds1x2: [("1", 1.85), ("X", 4.20), ("2", 3.60)],
                  ouOdds: [("Über 2,5", 1.60), ("Unter 2,5", 2.30)]),
        RealMatch(id: "bl2", home: "Dortmund", away: "Leverkusen", flagHome: "🟡", flagAway: "⚫️",
                  when: "Sa 15:30",
                  odds1x2: [("1", 2.45), ("X", 3.70), ("2", 2.60)],
                  ouOdds: [("Über 2,5", 1.65), ("Unter 2,5", 2.20)]),
        RealMatch(id: "bl3", home: "Frankfurt", away: "Stuttgart", flagHome: "🦅", flagAway: "🔺",
                  when: "So 17:30",
                  odds1x2: [("1", 2.30), ("X", 3.60), ("2", 2.80)],
                  ouOdds: [("Über 2,5", 1.80), ("Unter 2,5", 1.95)]),
    ]),
    Competition(id: "pl", name: "Premier League", icon: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", sub: "20 Teams · Sa/So", isEvent: false, matches: [
        RealMatch(id: "pl1", home: "Man City", away: "Arsenal", flagHome: "🩵", flagAway: "❤️",
                  when: "Sa 18:30 · Etihad",
                  odds1x2: [("1", 2.10), ("X", 3.60), ("2", 3.20)],
                  ouOdds: [("Über 2,5", 1.70), ("Unter 2,5", 2.10)]),
        RealMatch(id: "pl2", home: "Liverpool", away: "Chelsea", flagHome: "🔴", flagAway: "🔵",
                  when: "So 17:30 · Anfield",
                  odds1x2: [("1", 1.95), ("X", 3.80), ("2", 3.50)],
                  ouOdds: [("Über 2,5", 1.62), ("Unter 2,5", 2.25)]),
    ]),
    Competition(id: "ll", name: "La Liga", icon: "🇪🇸", sub: "20 Teams · Sa/So", isEvent: false, matches: [
        RealMatch(id: "ll1", home: "Real Madrid", away: "Atlético", flagHome: "⚪️", flagAway: "🔴",
                  when: "Sa 21:00 · Derbi",
                  odds1x2: [("1", 1.90), ("X", 3.60), ("2", 3.90)],
                  ouOdds: [("Über 2,5", 1.85), ("Unter 2,5", 1.90)]),
        RealMatch(id: "ll2", home: "Barcelona", away: "Sevilla", flagHome: "🔵", flagAway: "⚪️",
                  when: "So 21:00 · Camp Nou",
                  odds1x2: [("1", 1.55), ("X", 4.40), ("2", 5.50)],
                  ouOdds: [("Über 2,5", 1.55), ("Unter 2,5", 2.40)]),
    ]),
    Competition(id: "cl", name: "Champions League", icon: "⭐️", sub: "K.-o.-Phase · Di/Mi", isEvent: false, matches: [
        RealMatch(id: "cl1", home: "FC Bayern", away: "Real Madrid", flagHome: "🔴", flagAway: "⚪️",
                  when: "Di 21:00 · Kracher",
                  odds1x2: [("1", 2.60), ("X", 3.50), ("2", 2.50)],
                  ouOdds: [("Über 2,5", 1.66), ("Unter 2,5", 2.18)]),
        RealMatch(id: "cl2", home: "Arsenal", away: "PSG", flagHome: "❤️", flagAway: "🔵",
                  when: "Mi 21:00",
                  odds1x2: [("1", 2.40), ("X", 3.40), ("2", 2.75)],
                  ouOdds: [("Über 2,5", 1.75), ("Unter 2,5", 2.05)]),
    ]),
    Competition(id: "dfb", name: "DFB-Pokal", icon: "🏅", sub: "K.-o. · Überraschungen", isEvent: false, matches: [
        RealMatch(id: "dfb1", home: "St. Pauli", away: "FC Bayern", flagHome: "🏴‍☠️", flagAway: "🔴",
                  when: "Di 20:45 · Millerntor",
                  odds1x2: [("1", 6.50), ("X", 4.60), ("2", 1.45)],
                  ouOdds: [("Über 2,5", 1.70), ("Unter 2,5", 2.10)]),
        RealMatch(id: "dfb2", home: "Hertha BSC", away: "Dortmund", flagHome: "🔷", flagAway: "🟡",
                  when: "Mi 20:45 · Olympiastadion",
                  odds1x2: [("1", 4.80), ("X", 4.00), ("2", 1.62)],
                  ouOdds: [("Über 2,5", 1.72), ("Unter 2,5", 2.08)]),
    ]),
]

// MARK: - Featured Bets (kuratierte Einzelquoten — tippbar unabhängig von Liga-Slots)

struct FeaturedBet: Identifiable {
    var id: String { matchID + pick }
    let matchID: String
    let market: String
    let pick: String
    let title: String
    let note: String
}

struct Outright: Identifiable {
    var id: String { team }
    let team: String
    let odds: Double
    let flag: String
}

let DEFAULT_OUTRIGHTS: [Outright] = [
    Outright(team: "Frankreich", odds: 2.55, flag: "🇫🇷"),
    Outright(team: "Argentinien", odds: 4.00, flag: "🇦🇷"),
    Outright(team: "Spanien", odds: 4.30, flag: "🇪🇸"),
    Outright(team: "England", odds: 4.50, flag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿"),
]

// Reihenfolge + Anzeige-Metadaten je Wettbewerb (für das Mapping der Live-Daten)
struct CompMeta { let id: String; let name: String; let icon: String; let sub: String; let isEvent: Bool }
let COMP_META: [CompMeta] = [
    CompMeta(id: "wm",  name: "WM 2026",           icon: "🏆", sub: "Event · für alle offen", isEvent: true),
    CompMeta(id: "bl",  name: "Bundesliga",        icon: "🇩🇪", sub: "Deutschland",            isEvent: false),
    CompMeta(id: "pl",  name: "Premier League",    icon: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", sub: "England",               isEvent: false),
    CompMeta(id: "ll",  name: "La Liga",           icon: "🇪🇸", sub: "Spanien",               isEvent: false),
    CompMeta(id: "cl",  name: "Champions League",  icon: "⭐️", sub: "Europa",                isEvent: false),
    CompMeta(id: "dfb", name: "DFB-Pokal",         icon: "🏅", sub: "K.-o. · Pokal",         isEvent: false),
]

// Länder-Flaggen für WM-Teamnamen; Vereins-/Unbekannt-Fallback ist ⚽️
let TEAM_FLAGS: [String: String] = [
    "Frankreich": "🇫🇷", "Spanien": "🇪🇸", "England": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "Argentinien": "🇦🇷",
    "Deutschland": "🇩🇪", "Brasilien": "🇧🇷", "Portugal": "🇵🇹", "Niederlande": "🇳🇱",
    "Italien": "🇮🇹", "Belgien": "🇧🇪", "Kroatien": "🇭🇷", "Marokko": "🇲🇦",
    "Norwegen": "🇳🇴", "Schweiz": "🇨🇭", "USA": "🇺🇸", "Mexiko": "🇲🇽",
]
func flagFor(_ team: String, isEvent: Bool) -> String {
    if let f = TEAM_FLAGS[team] { return f }
    return isEvent ? "🏳️" : "⚽️"
}

// MARK: - Captain's Six (Paarungen aus den vier Halbfinalisten)

let C6_PAIRS: [(String, String)] = [
    ("Frankreich", "Spanien"),
    ("England", "Argentinien"),
    ("Frankreich", "England"),
    ("Spanien", "Argentinien"),
    ("Frankreich", "Argentinien"),
    ("Spanien", "England"),
]

// MARK: - Live-Match (Simulation, ab Level 10) — Halbfinal-Szenario

struct LiveMatch {
    var lid: Int
    var min: Int = 63
    var gh: Int = 0
    var ga: Int = 1
    var done: Bool = false
    var odds: [String: Double] = ["NEXT|FR": 2.10, "NEXT|ES": 2.60, "NONE|X": 3.40]
    var drift: [String: Int] = [:]   // -1 fallend · 0 stabil · +1 steigend

    static let labels: [String: String] = [
        "NEXT|FR": "Frankreich trifft als Nächstes",
        "NEXT|ES": "Spanien trifft als Nächstes",
        "NONE|X": "Kein weiteres Tor",
    ]
    static let orderedKeys = ["NEXT|FR", "NEXT|ES", "NONE|X"]
}
