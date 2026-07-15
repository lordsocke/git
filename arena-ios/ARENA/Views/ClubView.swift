import SwiftUI

struct DuelTarget: Identifiable {
    let name: String
    var id: String { name }
}

struct ClubView: View {
    @EnvironmentObject var game: GameState
    @State private var chatInput = ""
    @State private var duelTarget: DuelTarget?
    @FocusState private var chatFocused: Bool

    var body: some View {
        ScrollView {
            if game.level < 8 {
                lockedView
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                    .padding(14)
            } else {
                TwoCol {
                    header
                    SectionHeader(title: "Club-Stadion", detail: "gemeinsam bauen · alle profitieren")
                    clubStadiumCard
                    SectionHeader(title: "Wochen-Chest", detail: "Stufe 4 / 6")
                    chestCard
                    SectionHeader(title: "Mitglieder · diese Woche", detail: "Antippen = Duell ⚔️")
                    membersCard
                    if !game.s.duels.isEmpty {
                        SectionHeader(title: "Tipp-Duelle", detail: "nur im Club · 5 % Gebühr")
                        duelsCard
                    }
                } right: {
                    SectionHeader(title: "Club-Chat", detail: "28 online")
                    chatCard
                    SectionHeader(title: "Derby", detail: "startet Fr 18:00")
                    LockedCard(icon: "⚔️", title: "FC Coinkickers vs. Spin City Royals",
                               text: "Club-vs-Club übers Wochenende: Tipp-Punkte + Liga- und Minigame-Punkte zählen. Sieger-Club erhält 25 Mio Coins + Wappen-Rahmen.")
                }
                .padding(14)
                .padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { chatFocused = false }
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .sheet(item: $duelTarget) { target in
            DuelSheet(opponent: target.name)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(red: 0.078, green: 0.102, blue: 0.212))
        }
    }

    private var duelsCard: some View {
        Card {
            ForEach(game.s.duels.prefix(6)) { d in
                HStack(spacing: 8) {
                    Text("⚔️").font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("vs. \(d.opponent) · \(d.matchLabel)")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                        Text("Du: \(d.myPickText) · \(d.opponent): \(d.oppPickText) · je \(fmtS(d.stake))")
                            .font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                    }
                    Spacer()
                    Text(duelStatusLabel(d))
                        .font(.system(size: 8, weight: .black)).kerning(0.8)
                        .foregroundStyle(duelStatusColor(d))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(duelStatusColor(d).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func duelStatusLabel(_ d: Duel) -> String {
        switch d.status {
        case "won": return "+\(fmtS(d.payout))"
        case "lost": return "VERLOREN"
        case "void": return "ERSTATTET"
        default: return "LÄUFT"
        }
    }
    private func duelStatusColor(_ d: Duel) -> Color {
        switch d.status {
        case "won": return Theme.green
        case "lost": return Theme.red
        case "void": return Theme.mut
        default: return Theme.blue
        }
    }

    private var lockedView: some View {
        Card {
            VStack(spacing: 10) {
                Text("🛡").font(.system(size: 40))
                Text("Clubs ab Level 8").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Text("Chat, gemeinsame Wochen-Chest, Club-Liga mit Auf- und Abstieg und das Derby gegen andere Clubs.\n\nDemo-Regie: „+5 Level“.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: 12) {
                Text("🛡").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("FC Coinkickers").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.text)
                    Text("Gold-Liga · Platz 3 / 20").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.gold2)
                    Text("28 / 40 Mitglieder · Club-Level 7").font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    // MARK: Club-Stadion — Gemeinschaftsbau: jeder spendet, alle bekommen den Bonus

    private var clubStadiumCard: some View {
        Card {
            ForEach(STADIUM_PARTS) { part in
                let lvl = game.clubStadiumLevel(part.id)
                let cost = game.clubStadiumCost(part.id)
                let pot = game.s.clubStadiumPot[part.id] ?? 0
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(part.icon).font(.system(size: 14))
                        Text("\(part.name) · Stufe \(lvl)\(lvl >= STADIUM_MAX_LEVEL ? " (max)" : "")")
                            .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                        Spacer()
                        if lvl < STADIUM_MAX_LEVEL {
                            Text("\(fmtS(pot)) / \(fmtS(cost))")
                                .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                                .foregroundStyle(Theme.gold2)
                        }
                    }
                    if lvl < STADIUM_MAX_LEVEL {
                        ProgressBar(value: Double(pot) / Double(cost))
                        HStack(spacing: 6) {
                            donateButton(part.id, 100)
                            donateButton(part.id, 500)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            HStack(spacing: 6) {
                Text("⚡ Club-Bonus: +\(String(format: "%.1f", 0.5 * Double(game.clubStadiumTotal)).replacingOccurrences(of: ".", with: ",")) % Arena Bonus für ALLE Mitglieder")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.gold2)
                Spacer()
                Text("max +10 %").font(.system(size: 9)).foregroundStyle(Theme.dim)
            }
            Text("Gemeinsamer Spenden-Topf je Ausbau — deine Mitglieder bauen mit. Dein Beitrag bisher: \(fmtS(game.s.clubDonated)).")
                .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
        }
    }

    private func donateButton(_ id: String, _ amount: Int) -> some View {
        Button {
            game.donateClubStadium(id, amount: amount)
        } label: {
            Text("+\(fmtS(amount))")
                .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                .clipShape(Capsule())
        }
        .disabled(game.s.coins < amount)
        .opacity(game.s.coins < amount ? 0.45 : 1)
    }

    private var chestCard: some View {
        Card {
            let pct = min(100, game.s.chestFill / 20)
            HStack {
                Text("Alle Einsätze zählen — auch ARENA Liga")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(pct) %").font(.system(size: 11, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.gold2)
            }
            ProgressBar(value: Double(pct) / 100)
            Text("Stufe 5 bei 2,0 Mio — Belohnung für alle Mitglieder.")
                .font(.system(size: 9.5)).foregroundStyle(Theme.mut)
        }
    }

    private var membersCard: some View {
        Card {
            memberRow("Du (Demo)", true, game.s.clubPts, fmtS(game.s.wagered + game.s.virtWagered),
                      fmtS(game.s.biggestWin), hitRate, me: true)
            memberRow("Lukas9", true, 1841, "12,4 Mio", "2,4 Mio", "58 %")
            memberRow("SarahT", true, 1512, "9,1 Mio", "880 T", "64 %")
            memberRow("MoBerlin", false, 1203, "7,7 Mio", "1,1 Mio", "41 %")
            memberRow("Kim_R", true, 986, "5,2 Mio", "620 T", "52 %")
            memberRow("StefanG", false, 544, "3,0 Mio", "450 T", "38 %")
        }
    }

    private var hitRate: String {
        game.s.betsPlaced > 0 ? "\(Int((100.0 * Double(game.s.betsWon) / Double(game.s.betsPlaced)).rounded())) %" : "–"
    }

    private func memberRow(_ name: String, _ online: Bool, _ pts: Int, _ wagered: String, _ topWin: String, _ hits: String, me: Bool = false) -> some View {
        Button {
            guard !me else { return }
            duelTarget = DuelTarget(name: name)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(online ? Theme.green : Theme.dim).frame(width: 6, height: 6)
                Text(name).font(.system(size: 10.5, weight: .bold)).foregroundStyle(me ? Theme.gold2 : Theme.text)
                if !me {
                    Text("⚔️").font(.system(size: 9)).opacity(0.55)
                }
                Spacer()
                Text(fmt(pts)).font(.system(size: 10).monospacedDigit()).foregroundStyle(me ? Theme.gold2 : Theme.mut).frame(width: 44, alignment: .trailing)
                Text(wagered).font(.system(size: 10).monospacedDigit()).foregroundStyle(me ? Theme.gold2 : Theme.mut).frame(width: 56, alignment: .trailing)
                Text(topWin).font(.system(size: 10).monospacedDigit()).foregroundStyle(me ? Theme.gold2 : Theme.mut).frame(width: 52, alignment: .trailing)
                Text(hits).font(.system(size: 10).monospacedDigit()).foregroundStyle(me ? Theme.gold2 : Theme.mut).frame(width: 36, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(me)
    }

    private var chatCard: some View {
        Card {
            ForEach(Array(game.chatLog.suffix(10).enumerated()), id: \.offset) { _, msg in
                let me = msg.0 == "Du"
                HStack {
                    if me { Spacer() }
                    VStack(alignment: .leading, spacing: 1) {
                        if !me {
                            Text(msg.0).font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.gold2)
                        }
                        Text(msg.1).font(.system(size: 11)).foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(me ? Color(red: 0.14, green: 0.19, blue: 0.38) : Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    if !me { Spacer() }
                }
            }
            HStack(spacing: 8) {
                TextField("Nachricht an den Club…", text: $chatInput)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .focused($chatFocused)
                    .submitLabel(.send)
                    .onSubmit { sendChat() }
                Button {
                    sendChat()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                        .frame(width: 40, height: 36)
                        .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func sendChat() {
        let text = chatInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { chatFocused = false; return }
        game.chatLog.append(("Du", text))
        chatInput = ""
        chatFocused = false   // Tastatur nach dem Senden schließen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            let replies = ["Stark! 💪", "Haha nice 😄", "Bin dabei!", "Chest heute noch voll machen 🙏", "Mutig — aber die Quote passt!", "⚽ Heute Abend alle online?"]
            let names = ["Lukas9", "SarahT", "Kim_R"]
            game.chatLog.append((names.randomElement()!, replies.randomElement()!))
        }
    }
}

// MARK: - Duell-Sheet: Clubmitglied herausfordern (Tipp-Duell aufs nächste Liga-Spiel)

struct DuelSheet: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    let opponent: String
    @State private var myPick: String?
    @State private var stake = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Theme.line).frame(width: 40, height: 4).frame(maxWidth: .infinity)
                Text("⚔️ Duell gegen \(opponent)")
                    .font(.system(size: 15, weight: .black)).foregroundStyle(Theme.text)
                Text("Ihr wettet direkt gegeneinander auf das nächste ARENA-Liga-Spiel. Beide Einsätze wandern in den Pot — der Gewinner erhält 95 % (5 % Club-Gebühr). Liegt keiner richtig, gehen die Einsätze zurück.")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut)

                if let vm = game.v, vm.phase == .pause {
                    Card {
                        HStack {
                            HStack(spacing: 7) {
                                TeamBadge(team: VTEAMS[vm.home])
                                Text(VTEAMS[vm.home].name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                            }
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                Text("in \(max(0, Int(vm.until.timeIntervalSinceNow))) s")
                                    .font(.system(size: 10, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.gold2)
                            }
                            Spacer()
                            HStack(spacing: 7) {
                                Text(VTEAMS[vm.away].name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                                TeamBadge(team: VTEAMS[vm.away])
                            }
                        }
                        Text("DEIN TIPP").font(.system(size: 8.5, weight: .heavy)).kerning(1.2).foregroundStyle(Theme.dim)
                        HStack(spacing: 6) {
                            pickButton("1", VTEAMS[vm.home].short)
                            pickButton("X", "Remis")
                            pickButton("2", VTEAMS[vm.away].short)
                        }
                        Text("\(opponent) hält mit einem anderen Ausgang dagegen.")
                            .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                    }

                    StakeSlider(stake: $stake)

                    Button {
                        guard let pick = myPick else { return }
                        game.startDuel(opponent: opponent, myPick: pick, stake: stake)
                        dismiss()
                    } label: {
                        Text("Herausfordern — je \(fmtS(stake))")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .disabled(myPick == nil)
                    .opacity(myPick == nil ? 0.5 : 1)
                } else {
                    Card {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text("Gerade läuft ein Liga-Spiel — das Duell gilt für das nächste. Gleich wieder verfügbar!")
                                .font(.system(size: 11)).foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func pickButton(_ pick: String, _ label: String) -> some View {
        Button {
            myPick = pick
            Haptics.light()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(myPick == pick ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(myPick == pick
                            ? AnyShapeStyle(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Theme.card2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(myPick == pick ? Theme.goldDeep : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
