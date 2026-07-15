import SwiftUI

enum Theme {
    static let bg       = Color(red: 0.043, green: 0.063, blue: 0.125)   // #0b1020
    static let card     = Color(red: 0.086, green: 0.114, blue: 0.220)   // #161d38
    static let card2    = Color(red: 0.110, green: 0.145, blue: 0.278)   // #1c2547
    static let line     = Color(red: 0.157, green: 0.196, blue: 0.360)   // #28325c
    static let text     = Color(red: 0.949, green: 0.957, blue: 0.984)   // #f2f4fb
    static let mut      = Color(red: 0.545, green: 0.576, blue: 0.678)   // #8b93ad
    static let dim      = Color(red: 0.365, green: 0.396, blue: 0.518)   // #5d6584
    static let gold     = Color(red: 0.910, green: 0.702, blue: 0.231)   // #e8b33b
    static let gold2    = Color(red: 0.965, green: 0.831, blue: 0.471)   // #f6d478
    static let goldDeep = Color(red: 0.702, green: 0.510, blue: 0.118)   // #b3821e
    static let green    = Color(red: 0.243, green: 0.863, blue: 0.557)   // #3edc8e
    static let red      = Color(red: 1.000, green: 0.353, blue: 0.373)   // #ff5a5f
    static let blue     = Color(red: 0.357, green: 0.549, blue: 1.000)   // #5b8cff
}

// MARK: - Zahlformatierung (de-DE)

func fmt(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "de_DE")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

func fmtS(_ n: Int) -> String {
    let a = abs(n)
    if a >= 1_000_000_000 {
        return trimNum(Double(n) / 1e9) + " Mrd"
    }
    if a >= 1_000_000 {
        return trimNum(Double(n) / 1e6) + " Mio"
    }
    return fmt(n)
}

private func trimNum(_ v: Double) -> String {
    let s = String(format: "%.2f", v)
        .replacingOccurrences(of: ".", with: ",")
    // "1,50" -> "1,5", "2,00" -> "2"
    var out = s
    while out.contains(",") && (out.hasSuffix("0") || out.hasSuffix(",")) {
        let last = out.removeLast()
        if last == "," { break }
    }
    return out
}

func fmtOdd(_ o: Double) -> String {
    String(format: "%.2f", o).replacingOccurrences(of: ".", with: ",")
}

// MARK: - Haptik

enum Haptics {
    static var enabled = true   // aus den Einstellungen gesteuert
    static func light() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
