import SwiftUI

struct SportView: View {
    @EnvironmentObject var game: GameState
    @State private var expanded: String = "wm"

    var body: some View {
        ScrollView {
            TwoCol {
                oddsStatusBar
                liveCard
                SectionHeader(title: "Featured Bets", detail: "kuratiert · für alle offen")
                featuredCard
                SectionHeader(title: "Wettbewerbe", detail: "\(game.usedLeagueSlots + 1) / \(game.leagueSlots + 1) offen · +1 Slot je 10 Level")
                if game.s.unlockedLeagues.isEmpty {
                    starterChooser
                }
                ForEach(game.competitions) { comp in
                    CompetitionCard(comp: comp, expanded: $expanded)
                }
                Text("Quotenquelle: Merkur Bets (Cashpoint-Feed), geladen über den ARENA-Server in Frankfurt. Over/Under: Demo-Werte. Wettbewerbe ohne aktuelle Spiele (z. B. Sommerpause) zeigen Demo-Fixtures.")
                    .font(.system(size: 9)).foregroundStyle(Theme.dim)
            } right: {
                SectionHeader(title: "Turniersieger · WM", detail: "Langzeitwette")
                outrightsCard
                SectionHeader(title: "Captain's Six", detail: "Wochen-Tippspiel")
                CaptainsSixCard()
                SectionHeader(title: "Meine Wetten", detail: betCount)
                myBets
            }
            .padding(14)
            .padding(.bottom, 30)
        }
    }

    // MARK: Quoten-Status (Live aus Frankfurt vs. Demo)

    private var statusColor: Color { game.oddsLive ? Theme.green : game.oddsReachable ? Theme.gold2 : Theme.mut }
    private var statusText: String { game.oddsLive ? "LIVE-QUOTEN" : game.oddsReachable ? "MERKUR (gecacht)" : "DEMO-QUOTEN" }

    private var oddsStatusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 9.5, weight: .heavy)).kerning(1)
                .foregroundStyle(statusColor)
            Text(oddsAge).font(.system(size: 9.5)).foregroundStyle(Theme.mut).lineLimit(1)
            Spacer()
            if game.oddsLoading {
                ProgressView().scaleEffect(0.6)
            } else {
                Button {
                    Task { await game.loadLiveOdds() }
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold2)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private var oddsAge: String {
        guard game.oddsReachable, let t = game.oddsFetchedAt else { return "eingebettete Demo-Quoten" }
        let mins = Int(max(0, Date().timeIntervalSince(t)) / 60)
        return mins <= 1 ? "Merkur · gerade aktualisiert" : "Merkur · vor \(mins) Min"
    }

    // MARK: Live (WM-Halbfinale, ab L10)

    @ViewBuilder
    private var liveCard: some View {
        if game.level < 10 {
            LockedCard(icon: "🔒", title: "Live-Wetten ab Level 10",
                       text: "Wette mit Coins auf laufende Spiele — mit Cash-out und 1,5× XP. (Demo: „+5 Level“, ggf. mehrfach)")
        } else {
            Card {
                HStack(spacing: 8) {
                    if game.live.done {
                        Text("BEENDET").font(.system(size: 9.5, weight: .black)).foregroundStyle(Theme.mut)
                    } else {
                        HStack(spacing: 5) {
                            Circle().fill(Theme.red).frame(width: 7, height: 7)
                            Text("LIVE \(game.live.min)′").font(.system(size: 10, weight: .black)).kerning(1).foregroundStyle(Theme.red)
                        }
                    }
                    Text("WM · Halbfinale (Simulation)").font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                    Spacer()
                    if !game.live.done { Text("1,5× XP").font(.system(size: 9.5)).foregroundStyle(Theme.mut) }
                }
                HStack {
                    HStack(spacing: 7) { Text("🇫🇷"); Text("Frankreich").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text) }
                    Spacer()
                    Text("\(game.live.gh):\(game.live.ga)")
                        .font(.system(size: 15, weight: .black).monospacedDigit()).foregroundStyle(Theme.gold2)
                    Spacer()
                    HStack(spacing: 7) { Text("Spanien").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text); Text("🇪🇸") }
                }
                if !game.live.done {
                    HStack(spacing: 6) {
                        ForEach(LiveMatch.orderedKeys, id: \.self) { k in
                            let parts = k.split(separator: "|").map(String.init)
                            let key = "live|\(k)"
                            OddButton(
                                label: LiveMatch.labels[k] ?? k,
                                odds: game.live.odds[k] ?? 0,
                                selected: game.isSelected(key),
                                disabled: game.live.min >= 85,
                                drift: game.live.drift[k] ?? 0
                            ) {
                                game.toggleSelect(SlipItem(
                                    key: key, matchID: "live", market: parts[0], pick: parts[1],
                                    odds: game.live.odds[k] ?? 0,
                                    label: LiveMatch.labels[k] ?? k,
                                    sub: "LIVE · Frankreich – Spanien",
                                    kind: .live, vid: nil, lid: game.s.liveSeq))
                            }
                        }
                    }
                    if game.live.min >= 85 {
                        Text("Wettannahme geschlossen (ab 85′).")
                            .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                    }
                }
            }
        }
    }

    // MARK: Featured Bets

    private var featuredCard: some View {
        Card {
            ForEach(game.featuredBets) { f in
                if let match = game.competitions.flatMap({ $0.matches }).first(where: { $0.id == f.matchID }),
                   let odds = match.odd(market: f.market, pick: f.pick) {
                    let key = "\(match.id)|\(f.market)|\(f.pick)"
                    let settled = game.s.settledMatches[match.id] != nil
                    HStack(spacing: 10) {
                        Text("⚡️").font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.title).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                            Text(f.note + " · \(match.home) – \(match.away)")
                                .font(.system(size: 9)).foregroundStyle(Theme.mut).lineLimit(1)
                        }
                        Spacer()
                        OddButton(label: pickShort(f, match), odds: odds,
                                  selected: game.isSelected(key), disabled: settled) {
                            game.toggleSelect(SlipItem(
                                key: key, matchID: match.id, market: f.market, pick: f.pick, odds: odds,
                                label: pickLabel(f, match), sub: "\(match.home) – \(match.away)",
                                kind: .real, vid: nil, lid: nil))
                        }
                        .frame(width: 86)
                    }
                    .padding(.vertical, 2)
                }
            }
            Text("Kuratierte Quoten der Redaktion — unabhängig von deinen Liga-Slots tippbar. Keine Quoten-Boosts: gleiche faire Quote für alle.")
                .font(.system(size: 9)).foregroundStyle(Theme.dim)
        }
    }

    private func pickShort(_ f: FeaturedBet, _ m: RealMatch) -> String {
        guard f.market == "1X2" else { return f.pick }
        return f.pick == "1" ? m.home : f.pick == "2" ? m.away : "Remis"
    }
    private func pickLabel(_ f: FeaturedBet, _ m: RealMatch) -> String {
        f.market == "1X2"
            ? (f.pick == "1" ? "\(m.home) gewinnt" : f.pick == "2" ? "\(m.away) gewinnt" : "Unentschieden")
            : "\(f.pick) Tore"
    }

    // MARK: Start-Liga wählen

    private var starterChooser: some View {
        Card {
            Text("🏁 Wähle deine Start-Liga")
                .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.text)
            Text("Du startest mit einem Wettbewerb deiner Wahl — alle 10 Level schaltest du einen weiteren Slot frei. Die WM ist als Event für alle offen.")
                .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
            ForEach(game.competitions.filter { !$0.isEvent }) { c in
                Button {
                    game.chooseLeague(c)
                    expanded = c.id
                } label: {
                    HStack(spacing: 10) {
                        Text(c.icon).font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                            Text(c.sub).font(.system(size: 9)).foregroundStyle(Theme.mut)
                        }
                        Spacer()
                        Text("Wählen")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Turniersieger

    @ViewBuilder
    private var outrightsCard: some View {
        Card {
            if let winner = game.s.tournamentWinner {
                Text("🏆 Weltmeister: \(winner)")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text("Turnier entschieden — Langzeitwetten sind abgerechnet.")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
            } else {
                let cols = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(game.liveOutrights) { o in
                        let key = "out|WIN|\(o.team)"
                        OddButton(label: "\(o.flag) \(o.team)", odds: o.odds, selected: game.isSelected(key)) {
                            game.toggleSelect(SlipItem(
                                key: key, matchID: "out", market: "WIN", pick: o.team, odds: o.odds,
                                label: "Turniersieger: \(o.team)", sub: "WM 2026 · Langzeitwette",
                                kind: .outright, vid: nil, lid: nil))
                        }
                    }
                }
                Button("🏆 Turnier simulieren (Demo)") { game.simulateTournament() }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Meine Wetten

    private var betCount: String {
        let open = game.s.bets.filter { $0.status == .open }.count
        return game.s.bets.isEmpty ? "" : "\(open) offen · \(game.s.bets.count) gesamt"
    }

    @ViewBuilder
    private var myBets: some View {
        if game.s.bets.isEmpty {
            Text("Noch keine Wetten. Tippe auf eine Quote!")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        } else {
            if !game.compsWithOpenLegs.isEmpty {
                // Demo-Pfad: settlet auch Featured-Wetten auf noch gesperrte Ligen
                Button("⚡ Alle offenen Spieltage simulieren (Demo)") { game.simulateAllOpen() }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            ForEach(game.s.bets) { bet in
                BetCard(bet: bet)
            }
        }
    }
}

// MARK: - Wettbewerbs-Karte (Slotomania-Muster: Karte je Liga, aufklappbar)

struct CompetitionCard: View {
    @EnvironmentObject var game: GameState
    let comp: Competition
    @Binding var expanded: String

    private var available: Bool { game.isLeagueAvailable(comp) }
    private var slotFree: Bool { game.usedLeagueSlots < game.leagueSlots }
    private var nextSlotLevel: Int { game.usedLeagueSlots * 10 }

    var body: some View {
        Card {
            HStack(spacing: 10) {
                // Kopfzeile: Tippen klappt auf/zeigt Hinweis — Freischalten NUR über die
                // explizite Kapsel (kein versehentlicher Slot-Verbrauch durch Zeilen-Tap)
                Button {
                    if available {
                        withAnimation(.easeOut(duration: 0.2)) {
                            expanded = expanded == comp.id ? "" : comp.id
                        }
                    } else if game.s.unlockedLeagues.isEmpty {
                        game.toast("🏁 Wähle zuerst oben deine Start-Liga.")
                    } else if slotFree {
                        game.toast("Tippe auf „Freischalten“, um deinen Slot für \(comp.name) zu nutzen.")
                    } else {
                        game.toast("🔒 Nächster Liga-Slot ab Level \(nextSlotLevel).")
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(comp.icon).font(.system(size: 17))
                            .frame(width: 36, height: 36)
                            .background(Theme.card2)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .opacity(available ? 1 : 0.5)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(comp.name)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(available ? Theme.text : Theme.dim)
                            Text(available ? "\(comp.matches.count) Spiele · \(comp.sub)" : comp.sub)
                                .font(.system(size: 9)).foregroundStyle(Theme.mut)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if comp.isEvent {
                    tag("EVENT", Theme.gold2)
                } else if available {
                    Image(systemName: expanded == comp.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                } else if game.s.unlockedLeagues.isEmpty {
                    tag("OBEN WÄHLEN", Theme.dim)
                } else if slotFree {
                    Button {
                        game.chooseLeague(comp)
                        expanded = comp.id
                    } label: {
                        Text("Freischalten")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    tag("🔒 SLOT AB LEVEL \(nextSlotLevel)", Theme.dim)
                }
            }

            if available && expanded == comp.id {
                ForEach(comp.matches) { m in
                    RealMatchCard(match: m)
                }
                HStack(spacing: 8) {
                    if !game.allSettled(in: comp) {
                        Button("⚡ Spieltag simulieren") { game.simulateMatchday(comp) }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)
                    } else {
                        Button("🔁 Spieltag neu ansetzen") { game.redoMatchday(comp) }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .black)).kerning(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Spiel-Karte (echte Spiele)

struct RealMatchCard: View {
    @EnvironmentObject var game: GameState
    let match: RealMatch

    var body: some View {
        let result = game.s.settledMatches[match.id]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if result != nil {
                    Text("BEENDET").font(.system(size: 9.5, weight: .black)).foregroundStyle(Theme.mut)
                }
                Text(match.when).font(.system(size: 9.5)).foregroundStyle(Theme.mut)
            }
            HStack {
                HStack(spacing: 7) {
                    Text(match.flagHome)
                    Text(match.home).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                }
                Spacer()
                Text(result.map { "\($0.gh):\($0.ga)" } ?? "vs")
                    .font(.system(size: 15, weight: .black).monospacedDigit()).foregroundStyle(Theme.gold2)
                Spacer()
                HStack(spacing: 7) {
                    Text(match.away).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(match.flagAway)
                }
            }
            HStack(spacing: 6) {
                ForEach(match.odds1x2, id: \.0) { pick, odds in
                    let key = "\(match.id)|1X2|\(pick)"
                    let short = pick == "1" ? "1 · " + match.home.prefix(3).uppercased()
                        : pick == "2" ? "2 · " + match.away.prefix(3).uppercased() : "X · Remis"
                    OddButton(label: short, odds: odds, selected: game.isSelected(key), disabled: result != nil) {
                        game.toggleSelect(SlipItem(
                            key: key, matchID: match.id, market: "1X2", pick: pick, odds: odds,
                            label: pick == "1" ? "\(match.home) gewinnt" : pick == "2" ? "\(match.away) gewinnt" : "Unentschieden",
                            sub: "\(match.home) – \(match.away)", kind: .real, vid: nil, lid: nil))
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(match.ouOdds, id: \.0) { pick, odds in
                    let key = "\(match.id)|OU|\(pick)"
                    OddButton(label: pick + " Tore", odds: odds, selected: game.isSelected(key), disabled: result != nil) {
                        game.toggleSelect(SlipItem(
                            key: key, matchID: match.id, market: "OU", pick: pick, odds: odds,
                            label: "\(pick) Tore", sub: "\(match.home) – \(match.away)", kind: .real, vid: nil, lid: nil))
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.bg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Wett-Karte

struct BetCard: View {
    @EnvironmentObject var game: GameState
    let bet: Bet

    var body: some View {
        Card {
            HStack {
                Text(bet.legs.count > 1 ? "\(bet.legs.count)er-Kombi" : "Einzelwette")
                    .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                Text("@ \(fmtOdd(bet.odds))")
                    .font(.system(size: 11.5, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.gold2)
                Spacer()
                Text(bet.status.label.uppercased())
                    .font(.system(size: 8, weight: .black)).kerning(1)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            ForEach(bet.legs) { leg in
                HStack(spacing: 4) {
                    Text(legDot(leg)).font(.system(size: 10, weight: .black)).foregroundStyle(legColor(leg))
                    Text(leg.icon).font(.system(size: 10))
                    (Text(leg.label).bold().foregroundColor(Theme.text)
                        + Text(" (\(leg.sub))").foregroundColor(Theme.dim))
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
            HStack {
                Text("Einsatz \(fmtS(bet.stake))")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.mut)
                Spacer()
                Text(payoutText)
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(bet.status == .won || bet.status == .cashout ? Theme.green : Theme.mut)
            }
            if game.canCashout(bet) {
                Button("💸 Cash-out: \(fmtS(game.cashoutValue(bet)))") {
                    game.cashout(bet)
                }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var statusColor: Color {
        switch bet.status {
        case .open, .cashout: return Theme.blue
        case .won: return Theme.green
        case .lost: return Theme.red
        case .refunded: return Theme.mut
        }
    }
    private var payoutText: String {
        switch bet.status {
        case .won, .cashout: return "+\(fmtS(bet.payout))"
        case .refunded: return "↩ \(fmtS(bet.stake))"
        case .open: return "mögl. \(fmtS(Int((Double(bet.stake) * bet.odds).rounded())))"
        case .lost: return "–"
        }
    }
    private func legDot(_ leg: BetLeg) -> String {
        switch leg.result {
        case .won: return "✓"
        case .lost: return "✗"
        case .void: return "Ø"
        case nil: return "…"
        }
    }
    private func legColor(_ leg: BetLeg) -> Color {
        switch leg.result {
        case .won: return Theme.green
        case .lost: return Theme.red
        case .void: return Theme.dim
        case nil: return Theme.blue
        }
    }
}

// MARK: - Captain's Six

struct CaptainsSixCard: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        if game.level < 20 {
            LockedCard(icon: "🔒", title: "Captain's Six — ab Level 20",
                       text: "Wöchentliches Gratis-Tippspiel: 6 Spiele richtig = Community-Jackpot (aktuell \(fmtS(game.s.c6.jackpot))).")
        } else {
            Card {
                Text("Woche \(game.s.c6.week) · Community-Jackpot: \(fmtS(game.s.c6.jackpot)) · 6/6 = Jackpot, ab 4/6 Teilpreise")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                ForEach(Array(C6_PAIRS.enumerated()), id: \.offset) { i, pair in
                    HStack(spacing: 6) {
                        Text("\(pair.0) – \(pair.1)" + resultSuffix(i))
                            .font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        ForEach(["1", "X", "2"], id: \.self) { k in
                            c6Button(i: i, k: k)
                        }
                    }
                }
                c6Footer
            }
        }
    }

    private func resultSuffix(_ i: Int) -> String {
        if let results = game.s.c6.results, results.indices.contains(i) {
            return "  (\(results[i]))"
        }
        return ""
    }

    private func c6Button(i: Int, k: String) -> some View {
        let selected = game.s.c6.picks[i] == k
        var border = selected ? Theme.goldDeep : Theme.line
        var fg = selected ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.text
        if let results = game.s.c6.results, results.indices.contains(i), selected {
            border = results[i] == k ? Theme.green : Theme.red
            fg = results[i] == k ? Theme.green : Theme.red
        }
        return Button {
            guard !game.s.c6.submitted else { return }
            game.s.c6.picks[i] = k
            game.save()
        } label: {
            Text(k)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(fg)
                .frame(width: 34, height: 26)
                .background(selected && game.s.c6.results == nil
                            ? AnyShapeStyle(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Theme.card2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(game.s.c6.submitted)
    }

    @ViewBuilder
    private var c6Footer: some View {
        if !game.s.c6.submitted {
            Button("Tippschein abgeben (\(game.s.c6.picks.count)/6)") { game.submitC6() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(game.s.c6.picks.count < 6)
                .opacity(game.s.c6.picks.count < 6 ? 0.5 : 1)
        } else if let hits = game.s.c6.hits {
            Text("\(hits) / 6 richtig — \(hits >= 6 ? "JACKPOT!" : hits >= 4 ? "Teilpreis kassiert!" : "diesmal kein Preis.")")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
            Button("📅 Neue Woche (Demo)") { game.nextC6Week() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        } else {
            Button("⚡ Auswertung simulieren (Demo)") { game.simulateC6() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }
}
