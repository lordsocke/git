import Foundation

// MARK: - Wett-Modell mit leg-weisem Settlement

enum LegKind: String, Codable {
    case real       // WM-Spiel (Pre-Match)
    case live       // Live-Match (echte Spiele)
    case virt       // ARENA Liga (virtuell)
    case outright   // Turniersieger
}

enum LegResult: String, Codable {
    case won, lost, void
}

struct BetLeg: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String        // "matchID|market|pick"
    let matchID: String
    let market: String     // "1X2" | "OU" | "NEXT" | "NONE" | "WIN"
    let pick: String
    let odds: Double
    let label: String
    let sub: String
    let kind: LegKind
    var vid: Int?          // virtuelles Spiel (Instanz)
    var lid: Int?          // Live-Match-Instanz
    var result: LegResult?

    var icon: String {
        switch kind {
        case .real: return "⚽"
        case .live: return "🔴"
        case .virt: return "🏟"
        case .outright: return "🏆"
        }
    }
}

enum BetStatus: String, Codable {
    case open, won, lost, cashout, refunded

    var label: String {
        switch self {
        case .open: return "Offen"
        case .won: return "Gewonnen"
        case .lost: return "Verloren"
        case .cashout: return "Cash-out"
        case .refunded: return "Erstattet"
        }
    }
}

struct Bet: Codable, Identifiable, Equatable {
    let id: Int
    var legs: [BetLeg]
    var stake: Int
    var odds: Double
    var status: BetStatus = .open
    var xpMult: Double
    var payout: Int = 0
}

// MARK: - Wettschein-Auswahl (vor Platzierung)

struct SlipItem: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let matchID: String
    let market: String
    let pick: String
    let odds: Double
    let label: String
    let sub: String
    let kind: LegKind
    var vid: Int?
    var lid: Int?

    func toLeg() -> BetLeg {
        BetLeg(key: key, matchID: matchID, market: market, pick: pick, odds: odds,
               label: label, sub: sub, kind: kind, vid: vid, lid: lid, result: nil)
    }
}
