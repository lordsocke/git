import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ScrollView {
            TwoCol {
                bonusCard
                SectionHeader(title: "Tages-Tipp", detail: "1× täglich · gratis")
                dailyPickCard
                SectionHeader(title: "Bonus-Minispiel", detail: "Kein Coin-Einsatz")
                minigameCard
                SectionHeader(title: "ARENA Liga · immer live", detail: "virtuell · ~92,5 %")
                LigaTeaserCard()
            } right: {
                SectionHeader(title: "Nächste Spiele · deine Wettbewerbe", detail: "Quick-Tipp")
                quickMatches
                SectionHeader(title: "Daily Challenges", detail: challengeCount)
                challengesCard
                SectionHeader(title: "Club-Feed · FC Coinkickers", detail: "Live")
                feedCard
            }
            .padding(14)
            .padding(.bottom, 30)
        }
    }

    // MARK: Bonus

    private var bonusCard: some View {
        Card {
            HStack(spacing: 13) {
                BonusRingButton()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arena Bonus").font(.system(size: 14.5, weight: .black)).foregroundStyle(Theme.text)
                    Text("Alle 3 h: Coins + 2 Freispiele, skaliert mit Level & Serie. Jeder 3. Claim startet zusätzlich das Bonus-Rad.")
                        .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i < game.s.ring
                                      ? AnyShapeStyle(LinearGradient(colors: [Theme.goldDeep, Theme.gold2], startPoint: .leading, endPoint: .trailing))
                                      : AnyShapeStyle(Color.white.opacity(0.09)))
                                .frame(width: 22, height: 7)
                        }
                        Text("\(game.s.ring) / 3 zum Special")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.mut)
                    }
                    HStack(spacing: 5) {
                        Text("🔥")
                        Text("×\(mult(game.streakMult)) Serie · 🏗 ×\(mult(game.stadiumMult)) · 🛡 ×\(mult(game.clubStadiumMult)) (Cap ×2,0)")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.gold2)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }

    // MARK: Tages-Tipp

    @ViewBuilder
    private var dailyPickCard: some View {
        Card {
            if let resolved = game.s.pick.resolved {
                Text(resolved == "won" ? "✅ Heute getroffen!" : resolved == "lost" ? "❌ Heute daneben." : "↩️ Tipp verfallen — Serie bleibt.")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text("Morgen gibt es den nächsten Tages-Tipp (Demo: „🌅 Neuer Tag“).")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                pickLadder
            } else if game.s.pick.choice != nil {
                Text("🎯 Dein Tipp: \(pickLabel(game.s.pick.choice ?? ""))")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text("Auf Spiel #\(game.s.pick.vid ?? 0) — Auflösung nach Schlusspfiff.")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                pickLadder
            } else if let vm = game.v, vm.phase == .pause {
                Text("Wer gewinnt \(VTEAMS[vm.home].name) – \(VTEAMS[vm.away].name)?")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    pickButton(VTEAMS[vm.home].short, "1")
                    pickButton("Remis", "X")
                    pickButton(VTEAMS[vm.away].short, "2")
                }
                pickLadder
            } else {
                Text("🎯 Der Tages-Tipp gilt für das nächste ARENA-Liga-Spiel — gleich wählbar (aktuell läuft ein Spiel).")
                    .font(.system(size: 11)).foregroundStyle(Theme.mut)
                pickLadder
            }
        }
    }

    private func pickLabel(_ c: String) -> String {
        c == "1" ? "Heimsieg" : c == "2" ? "Auswärtssieg" : "Unentschieden"
    }

    private func mult(_ v: Double) -> String {
        String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    private func pickButton(_ label: String, _ choice: String) -> some View {
        Button {
            game.setDailyPick(choice)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
    }

    private var pickLadder: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { n in
                Text(game.s.pickStreak >= n ? "🔥" : "\(n)")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(game.s.pickStreak >= n ? Theme.gold2 : Theme.dim)
                    .frame(width: 18, height: 18)
                    .background(game.s.pickStreak >= n ? Theme.gold.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text("Serie: \(game.s.pickStreak) · nächster Treffer +\(fmtS(game.scaled(40 * min(game.s.pickStreak + 1, 10))))")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.mut)
                .padding(.leading, 4)
        }
    }

    // MARK: Minigame

    private var minigameCard: some View {
        Button {
            game.showSlot = true
        } label: {
            HStack(spacing: 12) {
                Text("🎰")
                    .font(.system(size: 30))
                    .frame(width: 62, height: 56)
                    .background(LinearGradient(colors: [Color(red: 0.24, green: 0.16, blue: 0.39), Color(red: 0.11, green: 0.09, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arena Spins").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                    Text("Spielbar nur mit Freispielen aus Boni, Challenges & Level-Ups — Gewinne zahlen Coins.")
                        .font(.system(size: 10)).foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.leading)
                    Text("\(game.s.freeSpins) Freispiele verfügbar")
                        .font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Theme.green)
                }
                Spacer()
            }
            .padding(12)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.11, blue: 0.3), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Quick-Tipp

    private var quickMatches: some View {
        let list = Array(game.availableMatches.prefix(4))
        return Card {
            ForEach(list) { m in
                HStack(spacing: 7) {
                    Text(m.flagHome).font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(m.home) – \(m.away)")
                            .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(game.s.settledMatches[m.id].map { "Beendet \($0.gh):\($0.ga)" } ?? m.when)
                            .font(.system(size: 9)).foregroundStyle(Theme.dim)
                    }
                    Spacer()
                    if game.s.settledMatches[m.id] == nil {
                        ForEach(m.odds1x2, id: \.0) { pick, odds in
                            let key = "\(m.id)|1X2|\(pick)"
                            Button {
                                game.toggleSelect(SlipItem(
                                    key: key, matchID: m.id, market: "1X2", pick: pick, odds: odds,
                                    label: pick == "1" ? "\(m.home) gewinnt" : pick == "2" ? "\(m.away) gewinnt" : "Unentschieden",
                                    sub: "\(m.home) – \(m.away)", kind: .real, vid: nil, lid: nil))
                            } label: {
                                VStack(spacing: 1) {
                                    Text(pick).font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(game.isSelected(key) ? Color(red: 0.42, green: 0.3, blue: 0) : Theme.dim)
                                    Text(fmtOdd(odds)).font(.system(size: 10.5, weight: .heavy).monospacedDigit())
                                        .foregroundStyle(game.isSelected(key) ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.text)
                                }
                                .frame(width: 42)
                                .padding(.vertical, 4)
                                .background(game.isSelected(key)
                                            ? AnyShapeStyle(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                                            : AnyShapeStyle(Theme.card2))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(game.isSelected(key) ? Theme.goldDeep : Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if m.id != list.last?.id {
                    Divider().overlay(Color.white.opacity(0.05))
                }
            }
        }
    }

    // MARK: Challenges

    private var challengeCount: String {
        let done = CHALLENGE_DEFS.filter { game.s.challenges.done[$0.id] == true }.count
        return "\(done) / \(CHALLENGE_DEFS.count)"
    }

    private var challengesCard: some View {
        Card {
            ForEach(CHALLENGE_DEFS) { c in
                let val = min(game.s.challenges.vals[c.id] ?? 0, c.target)
                let done = game.s.challenges.done[c.id] == true
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text((done ? "✓ " : "") + c.label)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(done ? Theme.green : Theme.text)
                        ProgressBar(value: Double(val) / Double(c.target), green: done)
                    }
                    Spacer()
                    Text(done ? "✓" : "+\(fmtS(game.scaled(c.coins)))")
                        .font(.system(size: 10, weight: .heavy).monospacedDigit())
                        .foregroundStyle(done ? Theme.green : Theme.gold2)
                }
                .padding(.vertical, 2)
            }
            Text("Alle 4 = Tages-Chest (+\(fmtS(game.scaled(120))) · +2 Freispiele) — Belohnungen wachsen mit deinem Level. Reset täglich.")
                .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
        }
    }

    // MARK: Feed

    private var feedCard: some View {
        Card {
            feedRow("SA", Theme.gold, "SarahT", "Kombi durch! Frankreich + Über 2,5 ✅ +840.000")
            feedRow("LK", Theme.green, "Lukas9", "hat 2,4 Mio im Bonus-Rad-Jackpot gewonnen 🎡")
            feedRow("CL", Theme.blue, "Club", "Wochen-Chest zu \(min(100, game.s.chestFill / 20)) % gefüllt — weiter so!")
            feedRow("MB", Color(red: 1, green: 0.54, blue: 0.36), "MoBerlin", "Serie 6 beim Tages-Tipp 🔥 wer knackt die 7?")
        }
    }

    private func feedRow(_ initials: String, _ color: Color, _ name: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(initials)
                .font(.system(size: 9.5, weight: .black))
                .foregroundStyle(Theme.bg)
                .frame(width: 23, height: 23)
                .background(color)
                .clipShape(Circle())
            (Text(name).bold().foregroundColor(Theme.text) + Text(" \(text)").foregroundColor(Theme.mut))
                .font(.system(size: 11))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bonus-Ring (Countdown)

struct BonusRingButton: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Button {
                game.claimBonus()
            } label: {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 6.5)
                    Circle()
                        .trim(from: 0, to: game.bonusReady ? 1 : 1 - game.bonusCountdown / (3 * 3600))
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(game.bonusReady
                              ? AnyShapeStyle(RadialGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], center: .topLeading, startRadius: 4, endRadius: 60))
                              : AnyShapeStyle(RadialGradient(colors: [Color(red: 0.16, green: 0.21, blue: 0.39), Color(red: 0.08, green: 0.11, blue: 0.24)], center: .topLeading, startRadius: 4, endRadius: 60)))
                        .padding(9)
                    VStack(spacing: 1) {
                        Text(game.bonusReady ? "JETZT" : "BONUS IN")
                            .font(.system(size: 7.5, weight: .bold)).kerning(1)
                            .foregroundStyle(game.bonusReady ? Color(red: 0.42, green: 0.3, blue: 0) : Theme.mut)
                        Text(game.bonusReady ? "+\(fmtS(game.bonusAmount))" : countdownText)
                            .font(.system(size: 11.5, weight: .black).monospacedDigit())
                            .foregroundStyle(game.bonusReady ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.text)
                    }
                }
                .frame(width: 92, height: 92)
            }
            .buttonStyle(.plain)
        }
    }

    private var countdownText: String {
        let t = Int(game.bonusCountdown)
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Liga-Teaser

struct LigaTeaserCard: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        Card {
            if let vm = game.v {
                HStack(spacing: 8) {
                    TeamBadge(team: VTEAMS[vm.home])
                    Text("\(VTEAMS[vm.home].name) – \(VTEAMS[vm.away].name)")
                        .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    TeamBadge(team: VTEAMS[vm.away])
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Group {
                        switch vm.phase {
                        case .pause:
                            Text("Anstoß in \(max(0, Int(vm.until.timeIntervalSinceNow))) s — jetzt tippen!")
                        case .live:
                            Text("🔴 LIVE \(Int(vm.min))′ · \(vm.gh):\(vm.ga)")
                        case .ft:
                            Text("Schlusspfiff: \(vm.gh):\(vm.ga) · gleich geht's weiter")
                        }
                    }
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
            }
        }
    }
}
