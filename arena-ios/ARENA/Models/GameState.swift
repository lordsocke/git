import SwiftUI
import Combine
import UserNotifications

// MARK: - Persistierter Spielstand

struct Purchase: Codable, Identifiable {
    let id: Int
    let title: String
    let price: String
    let coins: Int
    let date: Date
}

let SHOP_PACKS: [(title: String, price: String, coins: Int)] = [
    ("Starter", "1,99 €", 3_000),
    ("Fan", "4,99 €", 8_000),
    ("Stammspieler", "9,99 €", 18_000),
    ("Kapitän", "24,99 €", 50_000),
    ("Legende", "49,99 €", 120_000),
]

struct ChallengeState: Codable {
    var day: Int?
    var vals: [String: Int] = [:]
    var done: [String: Bool] = [:]
    var chestDone = false
}

struct PickState: Codable {
    var day: Int?
    var vid: Int?
    var choice: String?
    var resolved: String?   // "won" | "lost" | "void"
}

struct C6State: Codable {
    var picks: [Int: String] = [:]
    var submitted = false
    var hits: Int?
    var results: [String]?
    var jackpot = 12_500
    var week = 1
}

// MARK: - Tipp-Duell (Club-Feature: 1-gegen-1 mit Escrow, Konzept Kap. 10.4)

struct Duel: Codable, Identifiable, Equatable {
    let id: Int
    let opponent: String
    let vid: Int
    let matchLabel: String
    let myPick: String
    let myPickText: String
    let oppPick: String
    let oppPickText: String
    let stake: Int
    var status: String = "open"   // open | won | lost | void
    var payout: Int = 0
}

struct SaveData: Codable {
    var coins = 1_000
    var xp = 0
    var ring = 0
    var claims = 0
    var bonusReadyAt: Date?
    var wheelPending = false
    var streak = 1
    var lastClaimDay: Int?
    var dayOffset = 0
    var freeSpins = 2
    var cards = 0
    var spins = 0
    var wagered = 0
    var virtWagered = 0
    var wonTotal = 0
    var biggestWin = 0
    var betsPlaced = 0
    var betsWon = 0
    var virtBets = 0
    var cashouts = 0
    var chestFill = 1_360
    var clubPts = 412
    var bets: [Bet] = []
    var betSeq = 0
    var settledMatches: [String: MatchResult] = [:]
    var matchdayRun = 1
    var tournamentWinner: String?
    var challenges = ChallengeState()
    var pick = PickState()
    var pickStreak = 0
    var pickBest = 0
    var lastPickDay: Int?
    var stadium: [String: Int] = [:]
    var table: [Int: TeamRecord] = [:]
    var vSeq = 0
    var liveSeq = 0
    var c6 = C6State()
    var duels: [Duel] = []
    var duelSeq = 0
    var duelsWon = 0
    var unlockedLeagues: [String] = []          // gewählte Liga-Slots (Events zählen nicht)
    var clubStadium: [String: Int] = [:]        // Club-Stadion: Stufe je Ausbau
    var clubStadiumPot: [String: Int] = [:]     // gemeinsamer Spenden-Topf je Ausbau
    var clubDonated = 0                         // eigener Beitrag (Statistik)
    // Launch-Paket: Konto, Mitteilungen, Spielerschutz, Shop
    var onboarded = false
    var ageConfirmed = false
    var playerName = "Du"
    var avatar = "⚽️"
    var appleLinked = false
    var notifBonus = false
    var hapticsOn = true
    var rgCheckMins = 30
    var rgPausedUntil: Date?
    var purchases: [Purchase] = []
    /// Ökonomie-Skala-Version. Wird bei fundamentalen Balancing-Umstellungen erhöht,
    /// damit alte Spielstände sauber auf die neue Skala zurückgesetzt werden.
    /// v2 = „Start klein → Millionär" (Start 1.000, aktivitätsbasierte XP, 13.07.2026).
    var econScale = 2

    init() {}

    /// Migrationsfester Decoder: Swifts synthetisiertes Decodable wirft bei
    /// fehlenden Keys — Default-Werte helfen dabei NICHT. Ohne diesen Init
    /// würde jedes App-Update mit neuen SaveData-Feldern alte Spielstände
    /// beim Laden scheitern lassen und still auf null zurücksetzen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            // try? flacht T?? zu T? ab (Swift 5) — ?? liefert den Default bei fehlendem Key/Typ-Mismatch
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        coins = d(.coins, 1_000)
        xp = d(.xp, 0)
        ring = d(.ring, 0)
        claims = d(.claims, 0)
        bonusReadyAt = (try? c.decodeIfPresent(Date.self, forKey: .bonusReadyAt)) ?? nil
        wheelPending = d(.wheelPending, false)
        streak = d(.streak, 1)
        lastClaimDay = (try? c.decodeIfPresent(Int.self, forKey: .lastClaimDay)) ?? nil
        dayOffset = d(.dayOffset, 0)
        freeSpins = d(.freeSpins, 2)
        cards = d(.cards, 0)
        spins = d(.spins, 0)
        wagered = d(.wagered, 0)
        virtWagered = d(.virtWagered, 0)
        wonTotal = d(.wonTotal, 0)
        biggestWin = d(.biggestWin, 0)
        betsPlaced = d(.betsPlaced, 0)
        betsWon = d(.betsWon, 0)
        virtBets = d(.virtBets, 0)
        cashouts = d(.cashouts, 0)
        chestFill = d(.chestFill, 1_360)
        clubPts = d(.clubPts, 412)
        bets = d(.bets, [])
        betSeq = d(.betSeq, 0)
        settledMatches = d(.settledMatches, [:])
        matchdayRun = d(.matchdayRun, 1)
        tournamentWinner = (try? c.decodeIfPresent(String.self, forKey: .tournamentWinner)) ?? nil
        challenges = d(.challenges, ChallengeState())
        pick = d(.pick, PickState())
        pickStreak = d(.pickStreak, 0)
        pickBest = d(.pickBest, 0)
        lastPickDay = (try? c.decodeIfPresent(Int.self, forKey: .lastPickDay)) ?? nil
        stadium = d(.stadium, [:])
        table = d(.table, [:])
        vSeq = d(.vSeq, 0)
        liveSeq = d(.liveSeq, 0)
        c6 = d(.c6, C6State())
        duels = d(.duels, [])
        duelSeq = d(.duelSeq, 0)
        duelsWon = d(.duelsWon, 0)
        unlockedLeagues = d(.unlockedLeagues, [])
        clubStadium = d(.clubStadium, [:])
        clubStadiumPot = d(.clubStadiumPot, [:])
        clubDonated = d(.clubDonated, 0)
        onboarded = d(.onboarded, false)
        ageConfirmed = d(.ageConfirmed, false)
        playerName = d(.playerName, "Du")
        avatar = d(.avatar, "⚽️")
        appleLinked = d(.appleLinked, false)
        notifBonus = d(.notifBonus, false)
        hapticsOn = d(.hapticsOn, true)
        rgCheckMins = d(.rgCheckMins, 30)
        rgPausedUntil = (try? c.decodeIfPresent(Date.self, forKey: .rgPausedUntil)) ?? nil
        purchases = d(.purchases, [])
        econScale = d(.econScale, 1)   // alte Stände haben keinen Key ⇒ 1

        // Einmalige Migration auf die „Start klein"-Skala (v2): alter Fortschritt lief
        // auf einer inkompatiblen Coin-/XP-Skala (Start 1 Mio, einsatzbasierte XP) ⇒
        // Fortschritt frisch starten, Identität + Einstellungen behalten.
        if econScale < 2 {
            coins = 1_000; xp = 0; ring = 0; claims = 0; bonusReadyAt = nil
            wheelPending = false; streak = 1; lastClaimDay = nil; freeSpins = 2
            cards = 0; spins = 0; wagered = 0; virtWagered = 0; wonTotal = 0
            biggestWin = 0; betsPlaced = 0; betsWon = 0; virtBets = 0; cashouts = 0
            chestFill = 1_360; clubPts = 412; bets = []; betSeq = 0
            challenges = ChallengeState(); pick = PickState(); pickStreak = 0; pickBest = 0
            lastPickDay = nil; stadium = [:]; c6 = C6State(); duels = []; duelSeq = 0
            duelsWon = 0; clubStadium = [:]; clubStadiumPot = [:]; clubDonated = 0
            econScale = 2
        }
    }
}

// MARK: - Challenge-Definitionen

struct ChallengeDef: Identifiable {
    let id: String
    let label: String
    let target: Int
    let coins: Int
    let freeSpins: Int
}

let CHALLENGE_DEFS: [ChallengeDef] = [
    ChallengeDef(id: "bets", label: "2 Tipps platzieren", target: 2, coins: 50, freeSpins: 1),
    ChallengeDef(id: "virt", label: "1 Wette in der ARENA Liga", target: 1, coins: 35, freeSpins: 1),
    ChallengeDef(id: "bonus", label: "2× Arena Bonus abholen", target: 2, coins: 45, freeSpins: 1),
    ChallengeDef(id: "spins", label: "5 Freispiele nutzen", target: 5, coins: 35, freeSpins: 1),
]

// MARK: - Bonus-Rad

struct WheelSegment: Identifiable {
    let id: Int
    let label: String
    let coinMult: Int?
    let freeSpins: Int?
    let cards: Int?
    let weight: Double
    let color: Color
}

let WHEEL_SEGMENTS: [WheelSegment] = [
    WheelSegment(id: 0, label: "2×", coinMult: 2, freeSpins: nil, cards: nil, weight: 26, color: Color(red: 0.17, green: 0.22, blue: 0.41)),
    WheelSegment(id: 1, label: "5 Spins", coinMult: nil, freeSpins: 5, cards: nil, weight: 14, color: Color(red: 0.11, green: 0.36, blue: 0.25)),
    WheelSegment(id: 2, label: "3×", coinMult: 3, freeSpins: nil, cards: nil, weight: 20, color: Color(red: 0.14, green: 0.19, blue: 0.35)),
    WheelSegment(id: 3, label: "15 Spins", coinMult: nil, freeSpins: 15, cards: nil, weight: 7, color: Color(red: 0.11, green: 0.36, blue: 0.25)),
    WheelSegment(id: 4, label: "5×", coinMult: 5, freeSpins: nil, cards: nil, weight: 13, color: Color(red: 0.17, green: 0.22, blue: 0.41)),
    WheelSegment(id: 5, label: "+3 Karten", coinMult: nil, freeSpins: nil, cards: 3, weight: 7, color: Color(red: 0.30, green: 0.23, blue: 0.46)),
    WheelSegment(id: 6, label: "8×", coinMult: 8, freeSpins: nil, cards: nil, weight: 9, color: Color(red: 0.14, green: 0.19, blue: 0.35)),
    WheelSegment(id: 7, label: "JACKPOT 25×", coinMult: 25, freeSpins: nil, cards: nil, weight: 2, color: Color(red: 0.54, green: 0.39, blue: 0.06)),
]

// MARK: - Stadion (Meta-Coin-Senke)

struct StadiumPart: Identifiable {
    let id: String
    let name: String
    let icon: String
}

let STADIUM_PARTS: [StadiumPart] = [
    StadiumPart(id: "tribune", name: "Tribüne", icon: "🏟"),
    StadiumPart(id: "flutlicht", name: "Flutlicht", icon: "💡"),
    StadiumPart(id: "rasen", name: "Hybridrasen", icon: "🌱"),
    StadiumPart(id: "fanshop", name: "Fanshop", icon: "🧣"),
]
let STADIUM_MAX_LEVEL = 5
func stadiumCost(level: Int) -> Int { 250 * Int(pow(2.0, Double(level))) }

// MARK: - Arena Spins (Minigame-Mathematik; im Produkt serverseitig)

enum SlotMath {
    static let symbols = ["📣", "👕", "👟", "⚽", "⭐", "🏆"]
    static let weights: [Double] = [27, 23, 20, 14, 10, 6]
    static let pay3: [Int: Int] = [0: 5, 1: 8, 2: 12, 3: 18, 4: 30, 5: 60]
    static let pay2: [Int: Int] = [3: 2, 4: 4, 5: 8]
    static let lines: [[Int]] = [[1, 1, 1], [0, 0, 0], [2, 2, 2], [0, 1, 2], [2, 1, 0]]

    static func roll() -> Int {
        var r = Double.random(in: 0..<weights.reduce(0, +))
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return i }
        }
        return weights.count - 1
    }

    /// grid[spalte][zeile]
    static func evaluate(grid: [[Int]], stake: Int) -> Int {
        let lineBet = Double(stake) / Double(lines.count)
        var total = 0.0
        for rows in lines {
            let s0 = grid[0][rows[0]], s1 = grid[1][rows[1]], s2 = grid[2][rows[2]]
            if s0 == s1 && s1 == s2, let m = pay3[s0] {
                total += lineBet * Double(m)
            } else if s0 == s1, let m = pay2[s0] {
                total += lineBet * Double(m)
            }
        }
        return Int(total.rounded())
    }
}

struct SpinOutcome {
    let grid: [[Int]]
    let win: Int
    let stakeBase: Int
}

// MARK: - GameState

@MainActor
final class GameState: ObservableObject {

    @Published var s = SaveData()

    // Wettbewerbe/Quoten — dynamisch: Start = Demo-Snapshot, Live-Abruf ersetzt sie
    @Published var competitions: [Competition] = DEFAULT_COMPETITIONS
    @Published var liveOutrights: [Outright] = DEFAULT_OUTRIGHTS
    @Published var oddsSource: String = "Demo-Snapshot"
    @Published var oddsFetchedAt: Date?
    @Published var oddsLive = false        // frisch vom Server (nicht stale)
    @Published var oddsReachable = false   // Server erreicht (echte Merkur-Daten, evtl. gecacht)
    @Published var oddsLoading = false

    // Transient
    @Published var v: VirtualMatch?
    @Published var live: LiveMatch
    @Published var slip: [SlipItem] = []
    @Published var stake = 20
    @Published var showSlip = false
    @Published var showSettings = false
    @Published var toastText: String?
    @Published var levelToast: String?
    @Published var bonusOverlay: (amount: Int, special: Bool)?
    @Published var showWheel = false
    @Published var showSlot = false
    @Published var bigWin: (title: String, amount: Int)?
    @Published var chatLog: [(String, String)] = [
        ("Lukas9", "Wer traut sich im Halbfinale an Spanien? Die 3,10 juckt schon 👀"),
        ("SarahT", "Ich geh safe auf Frankreich + Unter 2,5 😄"),
        ("Kim_R", "Chest heute Abend voll machen 💪"),
    ]

    let ticker = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    let liveTicker = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    private var lastLevel = 1
    private var toastQueue: [String] = []
    private var toastBusy = false
    private let storeKey = "arena.ios.v3"

    let stakeOptions = [10, 25, 50, 100]

    init() {
        live = LiveMatch(lid: 0)
        if let data = UserDefaults.standard.data(forKey: storeKey) {
            if let loaded = try? JSONDecoder().decode(SaveData.self, from: data) {
                s = loaded
            } else {
                // Korrupte/inkompatible Daten: Alt-Blob sichern, BEVOR save() ihn überschreibt
                UserDefaults.standard.set(data, forKey: storeKey + ".bak")
            }
        }
        // Alt-Stände normalisieren: unbekannte Liga-IDs entfernen (Slot-Leak),
        // überfüllte Club-Stadion-Töpfe in Stufen umwandeln
        s.unlockedLeagues = s.unlockedLeagues.filter { id in competitions.contains { $0.id == id && !$0.isEvent } }
        for part in STADIUM_PARTS where (s.clubStadiumPot[part.id] ?? 0) >= clubStadiumCost(part.id) {
            creditClubStadium(part.id, amount: 0, donor: "")
        }
        lastLevel = level
        Haptics.enabled = s.hapticsOn
        startVirtualMatch()
        restartLive()
        voidOrphans()
        ensureChallengeDay()
    }

    // MARK: Launch-Paket — Konto, Mitteilungen, Spielerschutz, Shop

    private var sessionStart = Date()
    private var lastRealityCheck = Date()

    var isPaused: Bool { (s.rgPausedUntil ?? .distantPast) > Date() }

    func completeOnboarding(name: String, avatar chosenAvatar: String, apple: Bool) {
        s.playerName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Du" : name.trimmingCharacters(in: .whitespaces)
        s.avatar = chosenAvatar
        s.appleLinked = apple
        s.ageConfirmed = true
        s.onboarded = true
        toast(apple ? "✅ Angemeldet (Demo) — willkommen, \(s.playerName)!" : "👋 Willkommen, \(s.playerName)! Du spielst als Gast.")
        save()
    }

    func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.s.notifBonus = granted
                self.toast(granted ? "🔔 Mitteilungen aktiv — wir melden uns, wenn dein Bonus bereit ist."
                                   : "Mitteilungen bleiben aus — jederzeit in den Einstellungen aktivierbar.")
                if granted { self.scheduleBonusNotification() }
                self.save()
            }
        }
    }

    /// Lokale Mitteilung zum Bonus-Zeitpunkt (echtes Feature, kein Stub).
    func scheduleBonusNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["bonusReady"])
        guard s.notifBonus, let readyAt = s.bonusReadyAt, readyAt > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Dein Arena Bonus ist bereit! 🎁"
        content.body = "+\(fmtS(bonusAmount)) Coins und 2 Freispiele warten auf dich."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, readyAt.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: "bonusReady", content: content, trigger: trigger))
    }

    func realityCheckTick() {
        guard Date().timeIntervalSince(lastRealityCheck) > Double(s.rgCheckMins) * 60 else { return }
        lastRealityCheck = Date()
        let mins = Int(Date().timeIntervalSince(sessionStart) / 60)
        toast("⏱ Reality-Check: Du spielst seit \(mins) Minuten. Mach gern eine Pause — deine Boni warten.")
        Haptics.medium()
    }

    func startPause(hours: Int) {
        s.rgPausedUntil = Date().addingTimeInterval(Double(hours) * 3600)
        showSettings = false
        save()
    }
    func endPauseDemo() {
        s.rgPausedUntil = nil
        toast("Demo: Pause aufgehoben. Im Produkt ist die Pause bindend.")
        save()
    }

    // TestFlight-Phase: Käufe kosten kein echtes Geld (Richards Vorgabe 14.07.) —
    // die Buttons schalten die Coins direkt frei. Echte Apple-IAP kommen mit B9.
    func buyPack(_ index: Int) {
        guard SHOP_PACKS.indices.contains(index) else { return }
        let pack = SHOP_PACKS[index]
        s.coins += pack.coins
        s.purchases.append(Purchase(id: s.purchases.count + 1, title: pack.title, price: pack.price, coins: pack.coins, date: Date()))
        toast("🎁 Testphase: „\(pack.title)“ kostenlos freigeschaltet — +\(fmtS(pack.coins)) Coins!")
        Haptics.success()
        save()
    }

    func setHaptics(_ on: Bool) {
        s.hapticsOn = on
        Haptics.enabled = on
        save()
    }

    var shareText: String {
        "Meine ARENA-Bilanz: Level \(level) (\(rank)) · \(s.betsPlaced) Tipps · Bestserie \(s.pickBest) 🔥 · größter Gewinn \(fmtS(s.biggestWin)) Coins. ⚽️ #ARENA"
    }

    func save() {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    // MARK: Tag / Demo-Zeit

    var dayNum: Int { Int(Date().timeIntervalSince1970 / 86_400) + s.dayOffset }

    // MARK: Level & XP — AKTIVITÄTS-basiert (bewusst von Coins entkoppelt).
    // XP zählt Handlungen (Tipp, Freispiel, Claim, Tages-Tipp …), nicht Einsatzhöhe.
    // Grund: Bei der Start-klein-Ökonomie (Start 1.000) würde einsatzgebundene XP
    // das Leveln blockieren; zugleich beseitigt das das frühere Leveling-Runaway.
    // Kalibriert (Ökonomie-Sim tune_startsmall.py): L8 ~Tag 4, L20 ~Tag 20, L50 ~Tag 100.
    // XP-Punkte je Aktion: Tipp 10 (Live ×1,5) · Freispiel 4 · Bonus-Claim 12 ·
    // Tages-Tipp 25 · Duell 10 · Captain's Six 30 · Stadion-Ausbau 15 · Club-Spende 8.
    func xpNeeded(for level: Int) -> Int { Int((70 * pow(Double(level), 0.76)).rounded()) }

    var level: Int {
        var l = 1, rest = s.xp
        while rest >= xpNeeded(for: l) && l < 200 { rest -= xpNeeded(for: l); l += 1 }
        return l
    }
    var xpInto: Int {
        var l = 1, rest = s.xp
        while rest >= xpNeeded(for: l) && l < 200 { rest -= xpNeeded(for: l); l += 1 }
        return rest
    }
    var xpNeed: Int { xpNeeded(for: level) }
    var rank: String {
        switch level {
        case 50...: return "Diamant"
        case 35...: return "Platin"
        case 20...: return "Gold"
        case 10...: return "Silber"
        default: return "Bronze"
        }
    }
    var maxCombo: Int { level >= 12 ? 4 : level >= 5 ? 2 : 1 }

    static let unlockMessages: [Int: String] = [
        5: "2er-Kombis freigeschaltet!",
        8: "Clubs freigeschaltet!",
        10: "Live-Wetten (echte Spiele) freigeschaltet!",
        12: "Größere Kombis (bis 4er) freigeschaltet!",
        20: "Captain’s Six freigeschaltet!",
    ]

    /// Aktivitäts-XP gutschreiben. `points` = feste Handlungs-Punkte (s. Tabelle oben),
    /// `mult` z. B. 1,5 für Live-Tipps. Bewusst NICHT vom Einsatz/Coin-Betrag abhängig.
    func addXP(_ points: Double, mult: Double = 1.0) {
        s.xp += max(1, Int((points * mult).rounded()))
        let newLevel = level
        if newLevel > lastLevel {
            for l in (lastLevel + 1)...newLevel {
                // Level-up-Bonus wächst mit derselben Kurve wie die Bonus-Basis (Start 300).
                let bonus = Int((300 * pow(1.11, Double(min(l, 55) - 1))).rounded())
                s.coins += bonus
                s.freeSpins += 3
                var msg = "Level \(l)! +\(fmtS(bonus)) Coins · +3 Freispiele"
                if let unlock = Self.unlockMessages[l] { msg += "\n🔓 \(unlock)" }
                levelToast = msg
            }
            lastLevel = newLevel
            Haptics.success()
            let shown = levelToast
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { [weak self] in
                if self?.levelToast == shown { self?.levelToast = nil }
            }
        }
        save()
    }

    // MARK: Toast-Warteschlange

    func toast(_ msg: String) {
        if toastQueue.count >= 4 { toastQueue.removeFirst() }
        toastQueue.append(msg)
        if !toastBusy { nextToast() }
    }
    private func nextToast() {
        guard !toastQueue.isEmpty else { toastBusy = false; return }
        toastBusy = true
        toastText = toastQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            self?.toastText = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self?.nextToast() }
        }
    }

    // MARK: Bonus-System (3h-Takt, Ring, Serie mit Lückenbruch)

    // Start-klein-Ökonomie (Start 1.000 Coins): kleine Anker, die über die Level ~1000×
    // wachsen ⇒ man klettert sich zum Millionär (Ökonomie-Sim tune_startsmall.py).
    var bonusBase: Int { Int((60 * pow(1.11, Double(min(level, 55) - 1))).rounded()) }
    /// Level-Skalierung für Festbeträge (Challenges, Tages-Tipp, Chest): dieselbe
    /// Kurve wie die Bonus-Basis (+11 %/Level, Cap L55). Der Max-Einsatz wächst mit
    /// +16,5 %/Level bewusst schneller ⇒ der Burn holt auf, die Balance plateaut in
    /// den Millionen statt weiterzuwuchern (Konzept Kap. 6.2/6.3).
    func scaled(_ base: Int) -> Int {
        Int((Double(base) * pow(1.11, Double(min(level, 55) - 1))).rounded())
    }
    var streakMult: Double { 1 + 0.07 * Double(min(s.streak, 7)) }
    /// Stadionausbau boostet den Arena Bonus (+1,5 % je Stadion-Level, max +30 %).
    /// Bewusst KEIN Quotenboost: Quoten bleiben für alle gleich (Fair Play, kein Pay-to-Win,
    /// Senken-Ökonomie bleibt intakt) — der Ausbau verzinst stattdessen die Faucet-Seite.
    var stadiumMult: Double { 1 + 0.015 * Double(stadiumTotal) }
    /// Club-Stadion: +0,5 % je gemeinsam gebauter Stufe für ALLE Mitglieder (max +10 %).
    var clubStadiumMult: Double { 1 + 0.005 * Double(clubStadiumTotal) }
    /// Gesamt-Multiplikator gedeckelt (Ökonomie-Leitplanke gegen Multiplikator-Stacking).
    var bonusTotalMult: Double { min(streakMult * stadiumMult * clubStadiumMult, 2.0) }

    // MARK: Live-Quoten laden (Azure-Fetcher, Frankfurt) — mit Demo-Fallback

    func loadLiveOdds() async {
        oddsLoading = true
        defer { oddsLoading = false }
        guard let r = await OddsService.fetch() else {
            oddsReachable = false
            oddsLive = false
            oddsSource = "Demo-Snapshot (offline)"
            return
        }
        applyOdds(r)
        // Flex-Cold-Start liefert oft gecachte (stale) Daten → einmal kurz nachladen,
        // damit die App meist auf frischen Merkur-Quoten landet.
        if r.stale {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if let r2 = await OddsService.fetch() { applyOdds(r2) }
        }
    }

    private func applyOdds(_ r: OddsService.Result) {
        competitions = r.competitions
        if !r.outrights.isEmpty { liveOutrights = r.outrights }
        oddsSource = r.source
        oddsFetchedAt = r.fetchedAt
        oddsReachable = true
        oddsLive = !r.stale
        s.unlockedLeagues = s.unlockedLeagues.filter { id in competitions.contains { $0.id == id && !$0.isEvent } }
    }

    func competition(ofMatch id: String) -> Competition? {
        competitions.first { $0.matches.contains { $0.id == id } }
    }

    /// Featured Bets dynamisch aus den aktuellen Fixtures ableiten (funktioniert mit
    /// Live- wie Demo-Daten): der jeweils erste Außenseiter-Tipp aus WM, CL und Pokal.
    var featuredBets: [FeaturedBet] {
        var out: [FeaturedBet] = []
        for cid in ["wm", "cl", "dfb", "pl"] {
            guard let c = competitions.first(where: { $0.id == cid && !$0.matches.isEmpty }),
                  let m = c.matches.first else { continue }
            let h = m.odd(market: "1X2", pick: "1") ?? 0
            let a = m.odd(market: "1X2", pick: "2") ?? 0
            // Außenseiter = höhere Quote; bei ausgeglichenem Spiel das Remis featuren
            let pick = abs(h - a) < 0.4 ? "X" : (a > h ? "2" : "1")
            let note = "\(c.name) · Quote \(fmtOdd(m.odd(market: "1X2", pick: pick) ?? 0))"
            out.append(FeaturedBet(matchID: m.id, market: "1X2", pick: pick,
                                   title: featuredTitle(pick, m), note: note))
            if out.count >= 3 { break }
        }
        return out
    }
    private func featuredTitle(_ pick: String, _ m: RealMatch) -> String {
        switch pick {
        case "1": return "\(m.home) schlägt \(m.away)"
        case "2": return "Außenseiter \(m.away) trotzt \(m.home)"
        default:  return "Remis: \(m.home) – \(m.away)"
        }
    }

    // MARK: Wettbewerbe — Start-Liga wählen, +1 Slot je 10 Level; Events immer offen
    var leagueSlots: Int {
        min(1 + level / 10, competitions.filter { !$0.isEvent }.count)
    }
    var usedLeagueSlots: Int { s.unlockedLeagues.count }
    func isLeagueAvailable(_ c: Competition) -> Bool { c.isEvent || s.unlockedLeagues.contains(c.id) }
    var availableMatches: [RealMatch] {
        competitions.filter { isLeagueAvailable($0) }.flatMap { $0.matches }
    }
    func chooseLeague(_ c: Competition) {
        guard !c.isEvent, !s.unlockedLeagues.contains(c.id) else { return }
        guard usedLeagueSlots < leagueSlots else {
            toast("🔒 Nächster Liga-Slot ab Level \(usedLeagueSlots * 10) — weiterspielen!")
            return
        }
        s.unlockedLeagues.append(c.id)
        toast("🏟 \(c.name) freigeschaltet — viel Erfolg!")
        Haptics.success()
        save()
    }
    var bonusAmount: Int { Int((Double(bonusBase) * bonusTotalMult).rounded()) }

    // MARK: Einsatz — dynamisch per Slider, Maximum am Level gecapt
    /// Max-Einsatz wächst +16,5 %/Level (schneller als die Faucets mit +11 %) ⇒ der Burn
    /// holt mit steigendem Level auf, sodass die Balance in den Millionen plateaut statt
    /// unbegrenzt zu wachsen (Konzept Kap. 6.3). Start L1: 40, Cap-Level 55 ≈ 150 T.
    var maxStake: Int {
        let raw = 40.0 * pow(1.165, Double(min(level, 55) - 1))
        return min(Int(raw / 10) * 10, 1_000_000)
    }
    let minStake = 10
    /// „Schöne“ Slider-Schrittweite, die mit dem Level mitwächst (~1/20 des Max-Einsatzes).
    var stakeStep: Int { max(minStake, (maxStake / 20) / 10 * 10) }
    var bonusReady: Bool { s.bonusReadyAt.map { $0 <= Date() } ?? true }
    var bonusCountdown: TimeInterval { max(0, s.bonusReadyAt?.timeIntervalSinceNow ?? 0) }

    func claimBonus() {
        guard bonusReady else { toast("⏳ Noch nicht bereit — Demo: „Bonus sofort bereit“"); return }
        let dn = dayNum
        if s.lastClaimDay != dn {
            s.streak = (s.lastClaimDay == dn - 1) ? s.streak + 1 : 1
            s.lastClaimDay = dn
        }
        s.ring += 1
        s.claims += 1
        let amount = bonusAmount
        let special = s.ring >= 3
        if special { s.ring = 0; s.wheelPending = true }
        // Gutschrift atomar mit dem Claim — das Overlay ist reine Zelebration
        s.coins += amount
        s.freeSpins += 2
        s.bonusReadyAt = Date().addingTimeInterval(3 * 3600)
        addXP(12)   // Bonus-Claim = feste Aktivitäts-XP
        bumpChallenge("bonus")
        scheduleBonusNotification()
        bonusOverlay = (amount, special)
        Haptics.medium()
        save()
    }

    func dismissBonus(thenWheel: Bool) {
        bonusOverlay = nil
        if thenWheel { showWheel = true }
    }

    func drawWheelSegment() -> WheelSegment {
        var r = Double.random(in: 0..<WHEEL_SEGMENTS.reduce(0) { $0 + $1.weight })
        for seg in WHEEL_SEGMENTS {
            r -= seg.weight
            if r <= 0 { return seg }
        }
        return WHEEL_SEGMENTS[0]
    }

    func applyWheel(_ seg: WheelSegment) -> String {
        var msg = ""
        if let m = seg.coinMult {
            let amt = bonusAmount * m
            s.coins += amt
            msg = "\(seg.label) — +\(fmtS(amt)) Coins!"
        }
        if let fs = seg.freeSpins {
            s.freeSpins += fs
            msg = "🎁 \(fs) Freispiele für Arena Spins!"
        }
        if let c = seg.cards {
            s.cards += c
            msg = "🃏 +\(c) Sammelkarten fürs Album!"
        }
        if seg.coinMult == 50 { Haptics.heavy() } else { Haptics.success() }
        s.wheelPending = false
        save()
        return msg
    }

    // MARK: Challenges (Gutschrift + Tages-Reset)

    func ensureChallengeDay() {
        if s.challenges.day != dayNum {
            s.challenges = ChallengeState(day: dayNum)
        }
    }
    func bumpChallenge(_ id: String, by n: Int = 1) {
        ensureChallengeDay()
        s.challenges.vals[id, default: 0] += n
        checkChallenges()
    }
    private func checkChallenges() {
        for c in CHALLENGE_DEFS {
            if s.challenges.done[c.id] != true && (s.challenges.vals[c.id] ?? 0) >= c.target {
                s.challenges.done[c.id] = true
                let reward = scaled(c.coins)
                s.coins += reward
                s.freeSpins += c.freeSpins
                toast("✅ Challenge: \(c.label) — +\(fmtS(reward)) · +\(c.freeSpins) Freispiel")
            }
        }
        if !s.challenges.chestDone && CHALLENGE_DEFS.allSatisfy({ s.challenges.done[$0.id] == true }) {
            s.challenges.chestDone = true
            let reward = scaled(120)
            s.coins += reward
            s.freeSpins += 2
            addXP(30)   // alle Tages-Challenges geschafft
            toast("🎁 Tages-Chest! +\(fmtS(reward)) Coins · +2 Freispiele")
            Haptics.success()
        }
        save()
    }

    // MARK: Arena Spins

    var spinStakeBase: Int { max(10, Int((Double(bonusBase) * 0.5).rounded())) }

    func playSpin() -> SpinOutcome? {
        guard s.freeSpins > 0 else { return nil }
        s.freeSpins -= 1
        s.spins += 1
        s.clubPts += 5
        bumpChallenge("spins")
        var grid: [[Int]] = []
        for _ in 0..<3 { grid.append([SlotMath.roll(), SlotMath.roll(), SlotMath.roll()]) }
        let stakeBase = spinStakeBase
        let win = SlotMath.evaluate(grid: grid, stake: stakeBase)
        if win > 0 {
            s.coins += win
            s.wonTotal += win
            s.biggestWin = max(s.biggestWin, win)
        }
        addXP(4)   // Freispiel = feste Aktivitäts-XP
        save()
        return SpinOutcome(grid: grid, win: win, stakeBase: stakeBase)
    }

    func celebrateSpin(_ outcome: SpinOutcome) {
        let mult = Double(outcome.win) / Double(outcome.stakeBase)
        if mult >= 15 { bigWin = ("MEGA WIN", outcome.win); Haptics.heavy() }
        else if mult >= 5 { bigWin = ("BIG WIN", outcome.win); Haptics.success() }
        else if outcome.win > 0 { Haptics.light() }
    }

    // MARK: Wettschein

    func isSelected(_ key: String) -> Bool { slip.contains { $0.key == key } }

    func toggleSelect(_ item: SlipItem) {
        if let idx = slip.firstIndex(where: { $0.key == item.key }) {
            slip.remove(at: idx)
            return
        }
        if item.kind == .virt, let vm = v, vm.suspended { toast("⛔ Tor! Märkte kurz gesperrt."); return }
        slip.removeAll { $0.matchID == item.matchID }
        slip.append(item)
        if slip.count > maxCombo {
            slip = Array(slip.suffix(maxCombo))
            toast(maxCombo == 1 ? "🔒 Kombiwetten ab Level 5" : "🔒 Größere Kombis ab Level 12 (max. \(maxCombo)er)")
        }
        Haptics.light()
    }

    var slipTotalOdds: Double { slip.reduce(1) { $0 * $1.odds } }

    func placeBet() {
        guard !slip.isEmpty else { return }
        guard s.coins >= stake else { toast("Nicht genug Coins für diesen Einsatz."); return }
        // Veraltete/geschlossene Märkte abweisen (Late-Betting-Schutz: 85′/80′)
        let stale = slip.filter { item in
            switch item.kind {
            case .real: return s.settledMatches[item.matchID] != nil
            case .virt:
                guard let vm = v else { return true }
                return item.vid != vm.vid || vm.phase == .ft || vm.suspended || (vm.phase == .live && vm.min >= 80)
            case .live: return live.done || live.min >= 85
            case .outright: return s.tournamentWinner != nil
            }
        }
        if !stale.isEmpty {
            slip.removeAll { item in stale.contains(where: { $0.key == item.key }) }
            toast("⚠️ Ein Markt ist nicht mehr verfügbar — Auswahl aktualisiert.")
            return
        }
        // Repricing: Live-/Liga-Legs zur aktuellen Quote; >5 % Drift ⇒ prüfen lassen
        var bigDrift = false
        slip = slip.map { item in
            var it = item
            let cur: Double?
            switch item.kind {
            case .live: cur = live.odds[item.market + "|" + item.pick]
            case .virt: cur = v?.odds[item.market + "|" + item.pick]
            default: cur = nil
            }
            if let c = cur {
                if abs(c - it.odds) / it.odds > 0.05 { bigDrift = true }
                it = SlipItem(key: it.key, matchID: it.matchID, market: it.market, pick: it.pick,
                              odds: c, label: it.label, sub: it.sub, kind: it.kind, vid: it.vid, lid: it.lid)
            } else if item.kind == .live || item.kind == .virt {
                bigDrift = true
            }
            return it
        }
        if bigDrift { toast("📉 Quoten haben sich geändert — bitte Wettschein prüfen."); return }

        stake = min(max(stake, minStake), maxStake)   // Level-Cap durchsetzen
        s.coins -= stake
        s.betsPlaced += 1
        s.wagered += stake
        addChest(stake)
        s.clubPts += max(1, stake / 10)
        bumpChallenge("bets")
        if slip.contains(where: { $0.kind == .virt }) {
            s.virtBets += 1
            s.virtWagered += stake
            bumpChallenge("virt")
        }
        let legs = slip.map { $0.toLeg() }
        let xpMult: Double = legs.contains { $0.kind == .live } ? 1.5
            : legs.contains { $0.kind == .real || $0.kind == .outright } ? 1.2 : 1.0
        s.betSeq += 1
        let bet = Bet(id: s.betSeq, legs: legs, stake: stake,
                      odds: legs.reduce(1) { $0 * $1.odds }, xpMult: xpMult)
        s.bets.insert(bet, at: 0)
        slip = []
        showSlip = false
        toast("✅ Tipp platziert — viel Glück!")
        Haptics.medium()
        save()
    }

    // MARK: Settlement-Engine (leg-weise; Void = Quote 1,0; alles void = Erstattung)

    func settleLegs(where matches: (BetLeg) -> Bool, result: (BetLeg) -> LegResult?) {
        for i in s.bets.indices {
            guard s.bets[i].status == .open else { continue }
            var changed = false
            for j in s.bets[i].legs.indices {
                let leg = s.bets[i].legs[j]
                guard leg.result == nil, matches(leg) else { continue }
                if let r = result(leg) {
                    s.bets[i].legs[j].result = r
                    changed = true
                }
            }
            if changed { resolveBet(at: i) }
        }
        save()
    }

    @discardableResult
    func resolveBet(at i: Int) -> Int {
        guard s.bets.indices.contains(i), s.bets[i].status == .open else { return 0 }
        let bet = s.bets[i]
        if bet.legs.contains(where: { $0.result == .lost }) {
            s.bets[i].status = .lost
            addXP(10, mult: bet.xpMult)   // Tipp abgerechnet (void/push)
            return 0
        }
        if bet.legs.contains(where: { $0.result == nil }) { return 0 }
        let wonLegs = bet.legs.filter { $0.result == .won }
        if wonLegs.isEmpty {
            s.bets[i].status = .refunded
            s.bets[i].payout = bet.stake
            s.coins += bet.stake
            toast("↩️ Wette ungültig — Einsatz zurückerstattet.")
            return 0
        }
        let eff = wonLegs.reduce(1.0) { $0 * $1.odds }
        let payout = Int((Double(bet.stake) * eff).rounded())
        s.bets[i].status = .won
        s.bets[i].payout = payout
        s.coins += payout
        s.wonTotal += payout
        s.betsWon += 1
        s.biggestWin = max(s.biggestWin, payout)
        addXP(10, mult: bet.xpMult)   // Tipp abgerechnet
        Haptics.success()
        return payout
    }

    /// Verwaiste Live-/Liga-Legs aus früheren Sitzungen erstatten; offenen Tages-Tipp verfallen lassen.
    func voidOrphans() {
        var voided = 0
        for i in s.bets.indices {
            guard s.bets[i].status == .open else { continue }
            var changed = false
            for j in s.bets[i].legs.indices {
                let leg = s.bets[i].legs[j]
                let staleReal = leg.kind == .real && !competitions.flatMap({ $0.matches }).contains(where: { $0.id == leg.matchID })
                let staleOut = leg.kind == .outright && s.tournamentWinner == nil
                    && !liveOutrights.contains(where: { $0.team == leg.pick })
                if leg.result == nil && (leg.kind == .virt || leg.kind == .live || staleReal || staleOut) {
                    s.bets[i].legs[j].result = .void
                    changed = true
                    voided += 1
                }
            }
            if changed { resolveBet(at: i) }
        }
        if s.pick.day == dayNum && s.pick.choice != nil && s.pick.resolved == nil {
            s.pick.resolved = "void"
        }
        // Offene Duelle aus alter Sitzung: Pot zurück an beide (Einsatz erstatten)
        for i in s.duels.indices where s.duels[i].status == "open" {
            s.duels[i].status = "void"
            s.duels[i].payout = s.duels[i].stake
            s.coins += s.duels[i].stake
            voided += 1
        }
        if voided > 0 { toast("↩️ Offene Live-/Liga-Wetten aus der letzten Sitzung wurden erstattet.") }
        save()
    }

    // MARK: Spieltag-Simulation (echte Spiele, je Wettbewerb)

    func allSettled(in c: Competition) -> Bool { c.matches.allSatisfy { s.settledMatches[$0.id] != nil } }
    func hasOpenLegs(in c: Competition) -> Bool {
        let ids = Set(c.matches.map { $0.id })
        return s.bets.contains { $0.status == .open && $0.legs.contains { $0.kind == .real && $0.result == nil && ids.contains($0.matchID) } }
    }

    func sampleOutcome(_ m: RealMatch) -> MatchResult {
        let inv = m.odds1x2.map { (key: $0.0, p: 1.0 / $0.1) }
        var r = Double.random(in: 0..<inv.reduce(0) { $0 + $1.p })
        var out = "2"
        for e in inv { r -= e.p; if r <= 0 { out = e.key; break } }
        let scores: [String: [(Int, Int)]] = [
            "1": [(1, 0), (2, 0), (2, 1), (3, 1)],
            "X": [(0, 0), (1, 1), (2, 2)],
            "2": [(0, 1), (0, 2), (1, 2), (1, 3)],
        ]
        let sc = scores[out]!.randomElement()!
        return MatchResult(out: out, gh: sc.0, ga: sc.1)
    }

    func simulateMatchday(_ c: Competition) {
        for m in c.matches where s.settledMatches[m.id] == nil {
            s.settledMatches[m.id] = sampleOutcome(m)
        }
        let ids = Set(c.matches.map { $0.id })
        settleLegs(where: { $0.kind == .real && ids.contains($0.matchID) }) { leg in
            guard let r = self.s.settledMatches[leg.matchID] else { return nil }
            let ok: Bool
            if leg.market == "1X2" { ok = r.out == leg.pick }
            else { ok = leg.pick.hasPrefix("Über") ? r.gh + r.ga > 2 : r.gh + r.ga <= 2 }
            return ok ? .won : .lost
        }
        toast("⚡ \(c.name): Spieltag simuliert.")
    }

    func redoMatchday(_ c: Competition) {
        for m in c.matches { s.settledMatches.removeValue(forKey: m.id) }
        // Annullierter Spieltag: bereits fixierte Legs offener Kombis werden void
        // (Buchmacher-Praxis) — sonst widersprechen Leg-Resultate den neuen Spielen
        let ids = Set(c.matches.map { $0.id })
        for i in s.bets.indices where s.bets[i].status == .open {
            var changed = false
            for j in s.bets[i].legs.indices
            where s.bets[i].legs[j].kind == .real && ids.contains(s.bets[i].legs[j].matchID) && s.bets[i].legs[j].result != nil {
                s.bets[i].legs[j].result = .void
                changed = true
            }
            if changed { resolveBet(at: i) }
        }
        s.matchdayRun += 1
        if c.id == "wm" { restartLive() }
        toast("🔁 \(c.name): Spieltag neu angesetzt (Demo) — Fortschritt bleibt.")
        save()
    }

    /// Featured Bets können auf noch gesperrte Wettbewerbe zeigen — dieser Demo-Pfad
    /// settlet alle Wettbewerbe mit eigenen offenen Legs (im Produkt settlen Spiele von selbst).
    var compsWithOpenLegs: [Competition] {
        competitions.filter { hasOpenLegs(in: $0) && !allSettled(in: $0) }
    }
    func simulateAllOpen() {
        for c in compsWithOpenLegs { simulateMatchday(c) }
    }

    func simulateTournament() {
        var r = Double.random(in: 0..<liveOutrights.reduce(0) { $0 + 1.0 / $1.odds })
        var winner = liveOutrights.first?.team ?? ""
        for o in liveOutrights { r -= 1.0 / o.odds; if r <= 0 { winner = o.team; break } }
        s.tournamentWinner = winner
        settleLegs(where: { $0.kind == .outright }) { leg in
            leg.pick == winner ? .won : .lost
        }
        toast("🏆 Weltmeister (Demo): \(winner)")
    }

    // MARK: Live-Match (zustandsgetriebene Quoten; ab Level 10)

    func liveFairOdds() -> [String: Double] {
        let minLeft = Double(max(0, 88 - live.min))
        let pGoal = 1 - exp(-0.045 * minLeft)
        func q(_ p: Double) -> Double { min(max(0.93 / max(p, 0.02), 1.05), 15) }
        return ["NEXT|FR": q(pGoal * 0.55), "NEXT|ES": q(pGoal * 0.45), "NONE|X": q(1 - pGoal)]
    }

    func restartLive() {
        s.liveSeq += 1
        // Offene Live-Legs der alten Instanz voiden — sonst stranden sie
        for i in s.bets.indices {
            guard s.bets[i].status == .open else { continue }
            var changed = false
            for j in s.bets[i].legs.indices where s.bets[i].legs[j].result == nil && s.bets[i].legs[j].kind == .live {
                s.bets[i].legs[j].result = .void
                changed = true
            }
            if changed { resolveBet(at: i) }
        }
        slip.removeAll { $0.kind == .live }
        live = LiveMatch(lid: s.liveSeq)
        live.odds = liveFairOdds()
        save()
    }

    func liveTick() {
        guard level >= 10, !live.done else { return }
        live.min = min(90, live.min + 1)
        if live.min < 88 && Double.random(in: 0..<1) < 0.045 {
            liveGoal(home: Double.random(in: 0..<1) < 0.55)
        }
        let next = liveFairOdds()
        for (k, val) in next {
            live.drift[k] = val > (live.odds[k] ?? val) ? 1 : val < (live.odds[k] ?? val) ? -1 : 0
        }
        live.odds = next
        if live.min >= 90 { liveFullTime() }
    }

    private func liveGoal(home: Bool) {
        if home { live.gh += 1 } else { live.ga += 1 }
        let scorer = home ? "FR" : "ES"
        toast("⚽ TOR! \(home ? "Frankreich" : "Spanien") trifft — die Quoten drehen!")
        Haptics.heavy()
        settleLegs(where: { $0.kind == .live && $0.lid == s.liveSeq }) { leg in
            if leg.market == "NEXT" { return leg.pick == scorer ? .won : .lost }
            if leg.market == "NONE" { return .lost }
            return nil
        }
    }

    private func liveFullTime() {
        live.done = true
        settleLegs(where: { $0.kind == .live && $0.lid == s.liveSeq }) { leg in
            leg.market == "NONE" ? .won : .lost
        }
    }

    // Cash-out: deterministisch, Anzeige = Auszahlung. p_fair = 0,93/Quote, Marge 7 %.
    func canCashout(_ bet: Bet) -> Bool {
        bet.status == .open && bet.legs.count == 1 && bet.legs[0].kind == .live
            && bet.legs[0].result == nil && !live.done && bet.legs[0].lid == s.liveSeq
    }
    func cashoutValue(_ bet: Bet) -> Int {
        let leg = bet.legs[0]
        let cur = live.odds[leg.market + "|" + leg.pick] ?? leg.odds
        let p = min(max(0.93 / cur, 0.02), 0.97)
        return Int(min(Double(bet.stake) * leg.odds * p * 0.93, Double(bet.stake) * leg.odds * 0.95).rounded())
    }
    func cashout(_ bet: Bet) {
        guard let i = s.bets.firstIndex(where: { $0.id == bet.id }), s.bets[i].status == .open else { return }
        let value = cashoutValue(s.bets[i])
        s.coins += value
        s.bets[i].status = .cashout
        s.bets[i].payout = value
        s.bets[i].legs[0].result = .void
        s.cashouts += 1
        addXP(10, mult: 1.5)   // Live-Cashout
        toast("💸 Cash-out: +\(fmtS(value)) Coins")
        Haptics.medium()
        save()
    }

    // MARK: ARENA Liga (virtuelle Spiele)

    func startVirtualMatch() {
        s.vSeq += 1
        var h = Int.random(in: 0..<VTEAMS.count)
        var a = Int.random(in: 0..<VTEAMS.count)
        if a == h { a = (a + 1 + Int.random(in: 0..<(VTEAMS.count - 1))) % VTEAMS.count }
        h = min(h, VTEAMS.count - 1); a = min(a, VTEAMS.count - 1)
        let q = vHomeShare(home: h, away: a)
        v = VirtualMatch(vid: s.vSeq, until: Date().addingTimeInterval(18), home: h, away: a,
                         q: q, odds: vOdds(q: q, gh: 0, ga: 0, t: 0))
        save()
    }

    func vTick() {
        // Tages-Rollover außerhalb des View-Updates behandeln
        if s.challenges.day != dayNum { ensureChallengeDay() }
        if s.pick.day != dayNum { ensurePickDay() }
        realityCheckTick()
        guard var vm = v else { startVirtualMatch(); return }
        let now = Date()
        switch vm.phase {
        case .pause:
            if now >= vm.until { vm.phase = .live; vm.min = 0 }
        case .live:
            if vm.suspended && now >= vm.suspUntil { vm.suspended = false }
            if !vm.suspended {
                vm.min = min(90, vm.min + 0.5)
                // Torfenster = 179 Ticks à 0,015 — exakt das λ der Preisbildung (V_LAMBDA)
                if vm.min < 90 && Double.random(in: 0..<1) < 0.015 {
                    // Torschütze folgt exakt dem Preismodell-Anteil q (Kalibrier-Invariante)
                    let home = Double.random(in: 0..<1) < vm.q
                    if home { vm.gh += 1 } else { vm.ga += 1 }
                    vm.events.append("\(Int(vm.min))′ ⚽ \(VTEAMS[home ? vm.home : vm.away].name)")
                    vm.suspended = true
                    vm.suspUntil = now.addingTimeInterval(2.5)
                    slip.removeAll { $0.kind == .virt && $0.vid == vm.vid }
                    vm.odds = vLiveOdds(vm)
                }
                if Int(vm.min) % 3 == 0 { vm.odds = vLiveOdds(vm) }
                if vm.min >= 90 {
                    vm.phase = .ft
                    vm.until = now.addingTimeInterval(7)
                    v = vm
                    settleVirtual(vm)
                    return
                }
            }
        case .ft:
            if now >= vm.until { startVirtualMatch(); return }
        }
        v = vm
    }

    private func settleVirtual(_ vm: VirtualMatch) {
        let out = vm.gh > vm.ga ? "1" : vm.gh < vm.ga ? "2" : "X"
        let total = vm.gh + vm.ga
        settleLegs(where: { $0.kind == .virt && $0.vid == vm.vid }) { leg in
            let ok: Bool
            if leg.market == "1X2" { ok = out == leg.pick }
            else { ok = leg.pick.hasPrefix("Über") ? total > 2 : total <= 2 }
            return ok ? .won : .lost
        }
        // Tages-Tipp auflösen
        if s.pick.vid == vm.vid, s.pick.choice != nil, s.pick.resolved == nil {
            s.lastPickDay = dayNum
            if s.pick.choice == out {
                s.pickStreak += 1
                s.pickBest = max(s.pickBest, s.pickStreak)
                let reward = scaled(40 * min(s.pickStreak, 10))
                s.coins += reward
                s.pick.resolved = "won"
                addXP(25)   // Tages-Tipp
                toast("🎯 Tages-Tipp richtig! Serie \(s.pickStreak) — +\(fmtS(reward))")
                Haptics.success()
            } else {
                s.pickStreak = 0
                s.pick.resolved = "lost"
                toast("🎯 Tages-Tipp daneben — Serie beginnt neu.")
            }
        }
        // Tipp-Duelle auflösen (Pot = 2×Einsatz, Gewinner erhält 95 % — 5 % Rake als Senke;
        // trifft keiner den Ausgang, gehen beide Einsätze zurück)
        for i in s.duels.indices where s.duels[i].status == "open" && s.duels[i].vid == vm.vid {
            let d = s.duels[i]
            if out == d.myPick {
                let pot = Int((Double(d.stake) * 2 * 0.95).rounded())
                s.duels[i].status = "won"
                s.duels[i].payout = pot
                s.coins += pot
                s.duelsWon += 1
                s.wonTotal += pot
                addXP(10)   // Duell gewonnen
                chatLog.append((d.opponent, ["Autsch. Revanche! 😅", "Gut getippt… diesmal. 😤", "Okay okay, verdient."].randomElement()!))
                toast("⚔️ Duell gegen \(d.opponent) gewonnen: +\(fmtS(pot))!")
                Haptics.success()
            } else if out == d.oppPick {
                s.duels[i].status = "lost"
                addXP(10)   // Duell abgerechnet
                chatLog.append((d.opponent, ["Easy. 😎 Revanche?", "Danke für die Coins! 🤝", "Gegen mich tippt man nicht. 😄"].randomElement()!))
                toast("⚔️ Duell gegen \(d.opponent) verloren.")
            } else {
                s.duels[i].status = "void"
                s.duels[i].payout = d.stake
                s.coins += d.stake
                toast("⚔️ Duell unentschieden — keiner lag richtig, Einsätze zurück.")
            }
        }
        // Tabelle
        func upd(_ team: Int, _ pts: Int) {
            var rec = s.table[team] ?? TeamRecord()
            rec.points += pts
            rec.played += 1
            s.table[team] = rec
        }
        if out == "1" { upd(vm.home, 3); upd(vm.away, 0) }
        else if out == "2" { upd(vm.home, 0); upd(vm.away, 3) }
        else { upd(vm.home, 1); upd(vm.away, 1) }
        // Club-Stadion: Mitglieder spenden im Hintergrund weiter (Demo-Simulation)
        simulateMemberDonations()
        save()
    }

    // MARK: Tages-Tipp

    func ensurePickDay() {
        if s.pick.day != dayNum {
            if s.pickStreak > 0, let last = s.lastPickDay, last < dayNum - 1 { s.pickStreak = 0 }
            s.pick = PickState(day: dayNum)
        }
    }
    func setDailyPick(_ choice: String) {
        guard let vm = v, vm.phase == .pause else { toast("⏱ Das Spiel läuft schon — gleich wieder!"); return }
        ensurePickDay()
        s.pick = PickState(day: dayNum, vid: vm.vid, choice: choice, resolved: nil)
        toast("🎯 Tages-Tipp gesetzt — viel Glück!")
        save()
    }

    /// Wochen-Chest: Einsätze füllen die Truhe; bei 2 Mio wird ausgeschüttet und neu gestartet
    /// (behebt die „tote Progression bei 100 %").
    func addChest(_ amount: Int) {
        s.chestFill += amount
        while s.chestFill >= 2_000 {
            s.chestFill -= 2_000
            let reward = scaled(100)
            s.coins += reward
            toast("🧰 Wochen-Chest geknackt! +\(fmtS(reward)) für alle Mitglieder — neue Truhe startet.")
            Haptics.success()
        }
    }

    // MARK: Tipp-Duell (nur im Club, ab Level 8)

    func startDuel(opponent: String, myPick: String, stake rawStake: Int) {
        guard level >= 8 else { toast("Duelle gibt es nur im Club (ab Level 8)."); return }
        guard let vm = v, vm.phase == .pause else { toast("⏱ Duelle nur vor dem Anstoß — gleich wieder!"); return }
        let stake = min(max(rawStake, minStake), maxStake)
        guard s.coins >= stake else { toast("Nicht genug Coins für diesen Einsatz."); return }
        s.coins -= stake
        s.wagered += stake
        addChest(stake)
        s.clubPts += max(1, stake / 10)
        // Der Gegner hält mit einem der beiden anderen Ausgänge dagegen (Demo-Simulation;
        // im Produkt: echte Annahme durch das Clubmitglied, Escrow serverseitig)
        let oppPick = ["1", "X", "2"].filter { $0 != myPick }.randomElement()!
        func pickText(_ p: String) -> String {
            p == "1" ? VTEAMS[vm.home].short : p == "2" ? VTEAMS[vm.away].short : "Remis"
        }
        s.duelSeq += 1
        let duel = Duel(id: s.duelSeq, opponent: opponent, vid: vm.vid,
                        matchLabel: "\(VTEAMS[vm.home].short) – \(VTEAMS[vm.away].short)",
                        myPick: myPick, myPickText: pickText(myPick),
                        oppPick: oppPick, oppPickText: pickText(oppPick),
                        stake: stake)
        s.duels.insert(duel, at: 0)
        chatLog.append((opponent, ["Bin dabei! 😤", "Angenommen — das wird nix für dich 😄", "Deal. Möge der Bessere tippen!"].randomElement()!))
        toast("⚔️ Duell steht: Du \(pickText(myPick)) vs. \(opponent) \(pickText(oppPick)) — je \(fmtS(stake))")
        Haptics.medium()
        save()
    }

    // MARK: Club-Stadion (Gemeinschaftsbau: alle spenden, alle profitieren)

    func clubStadiumLevel(_ id: String) -> Int { s.clubStadium[id] ?? 0 }
    var clubStadiumTotal: Int { STADIUM_PARTS.reduce(0) { $0 + clubStadiumLevel($1.id) } }
    /// Club-Stufe n kostet 2.500.000 × 2^(n−1) — bewusst ×10 der persönlichen Stufe.
    func clubStadiumCost(_ id: String) -> Int { 2_500 * Int(pow(2.0, Double(clubStadiumLevel(id)))) }

    /// Restkosten bis zur Maximalstufe (abzüglich Topf) — verhindert verbrannte Überschüsse.
    func clubStadiumRemaining(_ id: String) -> Int {
        var total = 0
        for stage in clubStadiumLevel(id)..<STADIUM_MAX_LEVEL {
            total += 2_500 * Int(pow(2.0, Double(stage)))
        }
        return max(0, total - (s.clubStadiumPot[id] ?? 0))
    }

    func donateClubStadium(_ id: String, amount rawAmount: Int) {
        guard level >= 8 else { toast("Das Club-Stadion gibt es ab Level 8."); return }
        let lvl = clubStadiumLevel(id)
        guard lvl < STADIUM_MAX_LEVEL else { toast("Bereits Maximalstufe!"); return }
        let amount = min(rawAmount, s.coins, clubStadiumRemaining(id))
        guard amount > 0 else { toast(s.coins < rawAmount ? "Nicht genug Coins." : "Dieser Ausbau ist bereits finanziert."); return }
        s.coins -= amount
        s.clubDonated += amount
        s.clubPts += max(1, amount / 10)
        addXP(8)   // Club-Spende
        creditClubStadium(id, amount: amount, donor: "Du")
        Haptics.medium()
        save()
    }

    /// Spende verbuchen (eigene wie simulierte Mitglieder-Spenden) und Stufen bauen.
    func creditClubStadium(_ id: String, amount: Int, donor: String) {
        var pot = (s.clubStadiumPot[id] ?? 0) + amount
        var lvl = clubStadiumLevel(id)
        while lvl < STADIUM_MAX_LEVEL && pot >= clubStadiumCost(id) {
            pot -= clubStadiumCost(id)
            lvl += 1
            s.clubStadium[id] = lvl
            let name = STADIUM_PARTS.first { $0.id == id }?.name ?? id
            toast("🏟 Club-Stadion: \(name) auf Stufe \(lvl)! Alle Mitglieder erhalten +0,5 % Bonus.")
            chatLog.append(("Lukas9", ["Stufe \(lvl)! Wir sind ein Bautrupp 💪", "Sauber, \(name) steht! 🏗", "Das Stadion wächst! 🎉"].randomElement()!))
            Haptics.success()
        }
        if lvl >= STADIUM_MAX_LEVEL && pot > 0 {
            // Überschuss nicht verbrennen: in den nächsten unfertigen Ausbau umbuchen
            s.clubStadiumPot[id] = 0
            if let next = STADIUM_PARTS.first(where: { clubStadiumLevel($0.id) < STADIUM_MAX_LEVEL && $0.id != id }) {
                creditClubStadium(next.id, amount: pot, donor: donor)
            }
            return
        }
        s.clubStadiumPot[id] = pot
        if donor != "Du", Int.random(in: 0..<4) == 0 {
            chatLog.append((donor, "Hab was in den Stadion-Topf gelegt 🧱"))
        }
    }

    /// Simulierte Mitglieder-Spenden (Demo): tröpfeln nach jedem Liga-Spiel ein.
    func simulateMemberDonations() {
        guard level >= 8 else { return }
        guard let part = STADIUM_PARTS.filter({ clubStadiumLevel($0.id) < STADIUM_MAX_LEVEL })
            .min(by: { (s.clubStadiumPot[$0.id] ?? 0) < (s.clubStadiumPot[$1.id] ?? 0) }) else { return }
        let donor = ["Lukas9", "SarahT", "Kim_R", "MoBerlin"].randomElement()!
        creditClubStadium(part.id, amount: Int.random(in: 40...140), donor: donor)
    }

    // MARK: Stadion (persönlich)

    func stadiumLevel(_ id: String) -> Int { s.stadium[id] ?? 0 }
    var stadiumTotal: Int { STADIUM_PARTS.reduce(0) { $0 + stadiumLevel($1.id) } }
    func upgradeStadium(_ id: String) {
        let lvl = stadiumLevel(id)
        guard lvl < STADIUM_MAX_LEVEL else { toast("Bereits Maximalstufe!"); return }
        let cost = stadiumCost(level: lvl)
        guard s.coins >= cost else { toast("Nicht genug Coins — Kosten: \(fmtS(cost))"); return }
        s.coins -= cost
        s.stadium[id] = lvl + 1
        addXP(15)   // Stadion-Ausbau
        toast("🏗 \(STADIUM_PARTS.first { $0.id == id }?.name ?? "") auf Stufe \(lvl + 1)!")
        Haptics.medium()
        save()
    }

    // MARK: Captain's Six

    func submitC6() {
        guard s.c6.picks.count == 6 else { return }
        s.c6.submitted = true
        toast("📋 Captain’s Six abgegeben!")
        save()
    }
    func simulateC6() {
        guard s.c6.submitted, s.c6.hits == nil else { return }   // Mehrfach-Auszahlung verhindern
        var results: [String] = []
        for _ in C6_PAIRS {
            var r = Double.random(in: 0..<100)
            if r < 42 { results.append("1") } else if r < 68 { results.append("X") } else { results.append("2") }
            r = 0
        }
        var hits = 0
        for (i, res) in results.enumerated() where s.c6.picks[i] == res { hits += 1 }
        s.c6.results = results
        s.c6.hits = hits
        var prize = 0
        if hits >= 6 { prize = s.c6.jackpot }
        else if hits == 5 { prize = scaled(2_000) }
        else if hits == 4 { prize = scaled(500) }
        if prize > 0 {
            s.coins += prize
            toast("🏆 Captain's Six: \(hits)/6 — +\(fmtS(prize)) Coins!")
            Haptics.heavy()
        } else {
            toast("Captain's Six: \(hits)/6 — knapp vorbei.")
        }
        addXP(30)   // Captain's Six gespielt
        save()
    }
    func nextC6Week() {
        let jackpot = (s.c6.hits ?? 0) >= 6 ? 12_500 : s.c6.jackpot + 2_500
        s.c6 = C6State(jackpot: jackpot, week: s.c6.week + 1)
        save()
    }

    // MARK: Demo-Regie

    func demoBonusReady() { s.bonusReadyAt = nil; toast("⏩ 3 Stunden übersprungen — Bonus bereit!"); save() }
    func demoLevels() {
        let cur = level
        var total = 0
        for i in 1..<(cur + 5) { total += xpNeeded(for: i) }
        s.xp = max(s.xp, total)
        let li = level
        if li > lastLevel {
            let unlock = Self.unlockMessages.keys.filter { $0 > cur && $0 <= li }.max().flatMap { Self.unlockMessages[$0] }
            levelToast = "Level \(li) erreicht!" + (unlock.map { "\n🔓 \($0)" } ?? "")
            lastLevel = li
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { [weak self] in self?.levelToast = nil }
        }
        toast("⬆ +5 Level (Demo)")
        save()
    }
    func demoCoins() { s.coins += 100_000; toast("🪙 +100 T Coins (Demo)"); save() }
    func demoSpins() { s.freeSpins += 10; toast("🎁 +10 Freispiele (Demo)"); save() }
    func demoNewDay() {
        s.dayOffset += 1
        ensureChallengeDay()
        ensurePickDay()
        toast("🌅 Neuer Tag (Demo) — Challenges & Tages-Tipp zurückgesetzt.")
        save()
    }
    func demoReset() {
        UserDefaults.standard.removeObject(forKey: storeKey)
        s = SaveData()
        lastLevel = 1
        slip = []
        startVirtualMatch()
        restartLive()
        toast("↺ Zurückgesetzt.")
    }
}
