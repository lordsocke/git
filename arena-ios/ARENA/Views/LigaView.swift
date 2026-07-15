import SwiftUI

struct LigaView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ScrollView {
            TwoCol {
                SectionHeader(title: "ARENA Liga · virtuelle Spielrunde", detail: "alle ~100 Sek.")
                matchCard
                Text("Simulierte Spiele mit fairen, transparenten Quoten (Auszahlungsquote ~92,5 %). Immer verfügbar — auch ohne echten Spieltag. Wetten zählen für XP, Challenges & Club.")
                    .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
            } right: {
                SectionHeader(title: "Tabelle", detail: tableDetail)
                tableCard
            }
            .padding(14)
            .padding(.bottom, 30)
        }
    }

    // MARK: Spiel-Karte

    @ViewBuilder
    private var matchCard: some View {
        if let vm = game.v {
            Card {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 8) {
                        switch vm.phase {
                        case .pause:
                            Text("ANSTOSS IN \(max(0, Int(vm.until.timeIntervalSinceNow))) s")
                                .font(.system(size: 10, weight: .black)).foregroundStyle(Theme.gold2)
                            Text("Spiel #\(vm.vid)").font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                        case .live:
                            HStack(spacing: 5) {
                                Circle().fill(Theme.red).frame(width: 7, height: 7)
                                Text("LIVE \(Int(vm.min))′").font(.system(size: 10, weight: .black)).kerning(1).foregroundStyle(Theme.red)
                            }
                            Text("Spiel #\(vm.vid) · 1,0× XP").font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                            if vm.suspended {
                                Spacer()
                                Text("⛔ TOR — MARKT GESPERRT")
                                    .font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.red)
                            }
                        case .ft:
                            Text("BEENDET").font(.system(size: 10, weight: .black)).foregroundStyle(Theme.mut)
                            Text("Spiel #\(vm.vid)").font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                        }
                    }
                }
                HStack {
                    HStack(spacing: 7) {
                        TeamBadge(team: VTEAMS[vm.home])
                        Text(VTEAMS[vm.home].name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    }
                    Spacer()
                    Text(vm.phase == .pause ? "vs" : "\(vm.gh):\(vm.ga)")
                        .font(.system(size: 15, weight: .black).monospacedDigit()).foregroundStyle(Theme.gold2)
                    Spacer()
                    HStack(spacing: 7) {
                        Text(VTEAMS[vm.away].name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                        TeamBadge(team: VTEAMS[vm.away])
                    }
                }
                if vm.phase == .ft {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("Nächstes Spiel in \(max(0, Int(vm.until.timeIntervalSinceNow))) s …")
                            .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                    }
                } else {
                    let closed = vm.suspended || (vm.phase == .live && vm.min >= 80)
                    oddsRows(vm: vm, disabled: closed)
                    if vm.phase == .live && vm.min >= 80 && !vm.suspended {
                        Text("Wettannahme geschlossen (ab 80′).")
                            .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                    }
                }
                if !vm.events.isEmpty {
                    Text(vm.events.joined(separator: " · "))
                        .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                }
            }
        }
    }

    @ViewBuilder
    private func oddsRows(vm: VirtualMatch, disabled: Bool) -> some View {
        HStack(spacing: 6) {
            vOddButton(vm: vm, market: "1X2", pick: "1", label: "1 · \(VTEAMS[vm.home].short)", disabled: disabled)
            vOddButton(vm: vm, market: "1X2", pick: "X", label: "X · Remis", disabled: disabled)
            vOddButton(vm: vm, market: "1X2", pick: "2", label: "2 · \(VTEAMS[vm.away].short)", disabled: disabled)
        }
        if vm.odds["OU|Über 2,5"] != nil {
            Text("TORE GESAMT").font(.system(size: 8.5, weight: .heavy)).kerning(1.2).foregroundStyle(Theme.dim)
            HStack(spacing: 6) {
                vOddButton(vm: vm, market: "OU", pick: "Über 2,5", label: "Über 2,5", disabled: disabled)
                vOddButton(vm: vm, market: "OU", pick: "Unter 2,5", label: "Unter 2,5", disabled: disabled)
            }
        }
    }

    @ViewBuilder
    private func vOddButton(vm: VirtualMatch, market: String, pick: String, label: String, disabled: Bool) -> some View {
        if let odds = vm.odds["\(market)|\(pick)"] {
            let key = "v\(vm.vid)|\(market)|\(pick)"
            OddButton(label: label, odds: odds, selected: game.isSelected(key), disabled: disabled) {
                let legLabel = market == "1X2"
                    ? (pick == "1" ? "\(VTEAMS[vm.home].name) gewinnt" : pick == "2" ? "\(VTEAMS[vm.away].name) gewinnt" : "Unentschieden")
                    : "\(pick) Tore"
                game.toggleSelect(SlipItem(
                    key: key, matchID: "v\(vm.vid)", market: market, pick: pick, odds: odds,
                    label: legLabel, sub: "ARENA Liga · \(VTEAMS[vm.home].name) – \(VTEAMS[vm.away].name)",
                    kind: .virt, vid: vm.vid, lid: nil))
            }
        }
    }

    // MARK: Tabelle

    private var tableDetail: String {
        let games = VTEAMS.indices.reduce(0) { $0 + (game.s.table[$1]?.played ?? 0) } / 2
        return "nach \(games) Spielen"
    }

    private var tableRows: [(team: VTeam, rec: TeamRecord)] {
        let mapped: [(team: VTeam, rec: TeamRecord)] = VTEAMS.map { t in
            (team: t, rec: game.s.table[t.id] ?? TeamRecord())
        }
        return mapped.sorted { a, b in
            if a.rec.points != b.rec.points { return a.rec.points > b.rec.points }
            return a.team.name < b.team.name
        }
    }

    private var tableCard: some View {
        Card {
            HStack {
                Text("TEAM").font(.system(size: 8, weight: .heavy)).kerning(1).foregroundStyle(Theme.dim)
                Spacer()
                Text("SPIELE").font(.system(size: 8, weight: .heavy)).kerning(1).foregroundStyle(Theme.dim).frame(width: 50, alignment: .trailing)
                Text("PUNKTE").font(.system(size: 8, weight: .heavy)).kerning(1).foregroundStyle(Theme.dim).frame(width: 50, alignment: .trailing)
            }
            ForEach(tableRows, id: \.team.id) { row in
                HStack {
                    TeamBadge(team: row.team, size: 18)
                    Text(row.team.name).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(row.rec.played)").font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Theme.mut).frame(width: 50, alignment: .trailing)
                    Text("\(row.rec.points)").font(.system(size: 10.5, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.gold2).frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 1)
            }
        }
    }
}
