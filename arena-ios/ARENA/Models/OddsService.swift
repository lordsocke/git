import Foundation

// MARK: - Live-Quoten von unserem Azure-Fetcher in Frankfurt
// Der Crawler läuft in Germany West Central (umgeht den Merkur-Geo-Block); die
// App holt die normalisierten Quoten von dort. Fällt der Abruf aus, bleibt der
// eingebettete Demo-Snapshot (DEFAULT_COMPETITIONS) aktiv.

enum OddsService {
    // Öffentlicher Endpoint des Fetchers (anonym, nur lesend).
    static let baseURL = "https://arena-odds-de.azurewebsites.net"

    // --- DTOs für das JSON-Vertrags-Schema ---
    struct Document: Decodable {
        let source: String
        let fetchedAt: String
        let stale: Bool
        let competitions: [Comp]
    }
    struct Comp: Decodable {
        let id: String
        let name: String
        let matches: [Match]
        let outrights: [OutrightDTO]?
    }
    struct Match: Decodable {
        let id: String
        let home: String
        let away: String
        let kickoff: String?
        let venue: String?
        let odds1x2: [String: Double]?
        let ou25: OU?
    }
    struct OU: Decodable { let over: Double?; let under: Double? }
    struct OutrightDTO: Decodable { let team: String; let odds: Double }

    struct Result {
        let competitions: [Competition]
        let outrights: [Outright]
        let source: String
        let fetchedAt: Date?
        let stale: Bool
    }

    /// Lädt /odds und mappt in das App-Modell. Wettbewerbe ohne Live-Spiele
    /// fallen auf ihre Demo-Fixtures zurück, damit die App nie leer ist.
    static func fetch() async -> Result? {
        guard let url = URL(string: baseURL + "/odds") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { return nil }

        let liveById = Dictionary(uniqueKeysWithValues: doc.competitions.map { ($0.id, $0) })
        var comps: [Competition] = []
        for meta in COMP_META {
            if let live = liveById[meta.id], !live.matches.isEmpty {
                let matches = live.matches.compactMap { mapMatch($0, meta: meta) }
                comps.append(Competition(id: meta.id, name: meta.name, icon: meta.icon,
                                         sub: meta.sub, isEvent: meta.isEvent, matches: matches))
            } else if let demo = DEFAULT_COMPETITIONS.first(where: { $0.id == meta.id }) {
                comps.append(demo)   // Sommerpause o.ä. → Demo-Fixtures
            }
        }

        // Outrights aus dem WM-Wettbewerb (falls geliefert), sonst Demo
        var outs: [Outright] = []
        if let wm = liveById["wm"], let o = wm.outrights, !o.isEmpty {
            outs = o.map { Outright(team: $0.team, odds: $0.odds, flag: flagFor($0.team, isEvent: true)) }
        } else {
            outs = DEFAULT_OUTRIGHTS
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fetched = fmt.date(from: doc.fetchedAt) ?? ISO8601DateFormatter().date(from: doc.fetchedAt)
        return Result(competitions: comps, outrights: outs, source: doc.source, fetchedAt: fetched, stale: doc.stale)
    }

    private static func mapMatch(_ m: Match, meta: CompMeta) -> RealMatch? {
        guard let o = m.odds1x2, let h = o["1"], let x = o["X"], let a = o["2"] else { return nil }
        var ou: [(String, Double)] = []
        if let over = m.ou25?.over, let under = m.ou25?.under {
            ou = [("Über 2,5", over), ("Unter 2,5", under)]
        }
        return RealMatch(
            id: m.id, home: m.home, away: m.away,
            flagHome: flagFor(m.home, isEvent: meta.isEvent),
            flagAway: flagFor(m.away, isEvent: meta.isEvent),
            when: kickoffLabel(m.kickoff, venue: m.venue),
            odds1x2: [("1", h), ("X", x), ("2", a)],
            ouOdds: ou)
    }

    private static func kickoffLabel(_ iso: String?, venue: String?) -> String {
        guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return venue ?? "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "EE dd.MM. · HH:mm"
        let base = df.string(from: d)
        return venue?.isEmpty == false ? "\(base) · \(venue!)" : base
    }
}
