import SwiftUI

// MARK: - Landscape-Chrome: Icon-Rail links · HUD oben · Wettschein als rechter Drawer

enum AppTab: String, CaseIterable, Identifiable {
    case lobby, sport, liga, club, me
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lobby: return "LOBBY"
        case .sport: return "SPORT"
        case .liga: return "LIGA"
        case .club: return "CLUB"
        case .me: return "ICH"
        }
    }
    var icon: String {
        switch self {
        case .lobby: return "house.fill"
        case .sport: return "soccerball"
        case .liga: return "sportscourt.fill"
        case .club: return "shield.fill"
        case .me: return "person.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var game: GameState
    @State private var tab: AppTab = .lobby

    var body: some View {
        GeometryReader { geo in
        ZStack {
            Theme.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                // Rail-Band bis an die physische linke Kante; die Icons werden um die
                // halbe Safe-Area nach links gerückt und sitzen damit MITTIG im Band
                // (statt rechts daran zu kleben) — die Dynamic Island (~37 pt Tiefe)
                // bleibt frei, weil die Icons erst bei ~41 pt beginnen.
                SideRail(tab: $tab)
                    .padding(.leading, -geo.safeAreaInsets.leading / 2)
                    .background(
                        Color(red: 0.032, green: 0.047, blue: 0.096)
                            .ignoresSafeArea(edges: [.leading, .top, .bottom])
                    )
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .vertical)
                VStack(spacing: 0) {
                    HUDBar()
                    page
                }
                // Inhalt nutzt die volle Breite bis zur rechten Kante und läuft
                // unter dem Home-Indikator weiter (Scroll-Inhalte haben Bottom-Padding).
                .ignoresSafeArea(edges: [.trailing, .bottom])
            }

            // Wettschein-FAB
            if !game.slip.isEmpty && !game.showSlip {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) { game.showSlip = true }
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(game.slip.count)")
                                    .font(.system(size: 10.5, weight: .heavy))
                                    .foregroundStyle(Theme.gold2)
                                    .frame(width: 19, height: 19)
                                    .background(Color(red: 0.24, green: 0.16, blue: 0))
                                    .clipShape(Circle())
                                Text("Wettschein")
                                    .font(.system(size: 12.5, weight: .heavy))
                                Text("@ " + fmtOdd(game.slipTotalOdds))
                                    .font(.system(size: 12.5, weight: .heavy).monospacedDigit())
                            }
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .clipShape(Capsule())
                            .shadow(color: Theme.gold.opacity(0.35), radius: 9, y: 4)
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 16)
                    }
                }
            }

            // Wettschein: rechter Drawer
            if game.showSlip {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeIn(duration: 0.2)) { game.showSlip = false } }
                HStack(spacing: 0) {
                    Spacer()
                    ScrollView {
                        BetSlipView()
                    }
                    .frame(width: 340)
                    .background(Color(red: 0.078, green: 0.102, blue: 0.212))
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                    .ignoresSafeArea(edges: [.vertical, .trailing])
                }
                .transition(.move(edge: .trailing))
            }

            overlays

            if !game.s.onboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(90)
            } else if game.isPaused {
                PauseOverlay()
                    .zIndex(89)
            }
        }
        .task { await game.loadLiveOdds() }   // echte Merkur-Quoten vom Frankfurt-Server
        .animation(.easeOut(duration: 0.25), value: game.showSlip)
        .animation(.easeInOut(duration: 0.35), value: game.s.onboarded)
        .onReceive(game.ticker) { _ in game.vTick() }
        .onReceive(game.liveTicker) { _ in game.liveTick() }
        .fullScreenCover(isPresented: $game.showSlot) {
            SlotView()
        }
        .sheet(isPresented: $game.showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(red: 0.078, green: 0.102, blue: 0.212))
        }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .lobby: LobbyView()
        case .sport: SportView()
        case .liga: LigaView()
        case .club: ClubView()
        case .me: ProfileView()
        }
    }

    @ViewBuilder
    private var overlays: some View {
        if let bonus = game.bonusOverlay {
            BonusClaimOverlay(amount: bonus.amount, special: bonus.special)
        }
        if game.showWheel {
            WheelOverlay()
        }
        if let win = game.bigWin {
            BigWinOverlay(title: win.title, amount: win.amount)
        }
        VStack {
            if let lvl = game.levelToast {
                Text(lvl)
                    .font(.system(size: 12, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Theme.gold.opacity(0.5), radius: 14, y: 6)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if let toast = game.toastText {
                Text(toast)
                    .font(.system(size: 11.5, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 15).padding(.vertical, 9)
                    .background(Color(red: 0.11, green: 0.15, blue: 0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
                    .padding(.bottom, 18)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.toastText)
        .animation(.easeInOut(duration: 0.3), value: game.levelToast)
        .allowsHitTesting(false)
    }
}

// MARK: - Icon-Rail (linke Navigation)

struct SideRail: View {
    @EnvironmentObject var game: GameState
    @Binding var tab: AppTab

    var body: some View {
        VStack(spacing: 6) {
            ForEach(AppTab.allCases) { t in
                Button {
                    tab = t
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 17, weight: .medium))
                        Text(t.label)
                            .font(.system(size: 8, weight: .heavy)).kerning(0.4)
                    }
                    .foregroundStyle(tab == t ? Theme.gold : Theme.dim)
                    .frame(width: 58, height: 50)
                    .background(tab == t ? Theme.gold.opacity(0.09) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        if t == .lobby && game.bonusReady {
                            Circle().fill(Theme.red).frame(width: 7, height: 7).offset(x: -8, y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .frame(width: 74)
    }
}

// MARK: - HUD (oben im Content-Bereich)

struct HUDBar: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: Double(game.xpInto) / Double(max(game.xpNeed, 1)))
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(game.level)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.gold2)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(game.s.avatar) \(game.s.playerName)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text("\(game.rank) · Season 1\(game.s.appleLinked ? "" : " · Gast")")
                    .font(.system(size: 8.5, weight: .semibold)).kerning(0.5)
                    .foregroundStyle(Theme.mut)
                    .textCase(.uppercase)
            }

            Spacer()

            Button { game.showSlot = true } label: {
                HStack(spacing: 4) {
                    Text("🎁")
                    Text("\(game.s.freeSpins) \(game.s.freeSpins == 1 ? "Freispiel" : "Freispiele")")
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                }
                .foregroundStyle(Theme.green)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.green.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.green.opacity(0.4), lineWidth: 1))
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(RadialGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep],
                                         center: .topLeading, startRadius: 1, endRadius: 14))
                    .frame(width: 19, height: 19)
                    .overlay(Text("A").font(.system(size: 9.5, weight: .black)).foregroundStyle(Color(red: 0.36, green: 0.24, blue: 0)))
                Text(fmtS(game.s.coins))
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.gold2)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.4), value: game.s.coins)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(LinearGradient(colors: [Theme.card2, Theme.card], startPoint: .top, endPoint: .bottom))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))

            Button {
                game.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.dim)
            }

            Menu {
                Button("⏩ Bonus sofort bereit") { game.demoBonusReady() }
                Button("⬆ +5 Level") { game.demoLevels() }
                Button("🪙 +100 T Coins") { game.demoCoins() }
                Button("🎁 +10 Freispiele") { game.demoSpins() }
                Button("🌅 Neuer Tag") { game.demoNewDay() }
                Button("↺ Zurücksetzen", role: .destructive) { game.demoReset() }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
