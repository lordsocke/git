import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ScrollView {
            TwoCol {
                HStack {
                    SectionHeader(title: "Statistiken", detail: "Season 1")
                    Spacer()
                    ShareLink(item: game.shareText) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 10, weight: .bold))
                            Text("Teilen").font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundStyle(Theme.gold2)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.gold.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                statsGrid
                SectionHeader(title: "Abzeichen", detail: "\(badges.filter { $0.2 }.count) / \(badges.count)")
                badgesCard
            } right: {
                SectionHeader(title: "Mein Stadion", detail: "Level \(game.stadiumTotal) / \(STADIUM_MAX_LEVEL * 4) · Coin-Senke")
                stadiumCard
                SectionHeader(title: "Coin-Shop", detail: "Demo · kein echter Kauf")
                shopCard
                SectionHeader(title: "Spielerschutz")
                rgCard
            }
            .padding(14)
            .padding(.bottom, 30)
        }
    }

    private var hitRate: String {
        game.s.betsPlaced > 0 ? "\(Int((100.0 * Double(game.s.betsWon) / Double(game.s.betsPlaced)).rounded())) %" : "–"
    }

    private var statsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        return LazyVGrid(columns: cols, spacing: 9) {
            StatCell(label: "Level", value: "\(game.level) · \(game.rank)")
            StatCell(label: "XP bis Level \(game.level + 1)", value: fmtS(game.xpNeed - game.xpInto))
            StatCell(label: "Tipps platziert", value: "\(game.s.betsPlaced)")
            StatCell(label: "Tipp-Trefferquote", value: hitRate)
            StatCell(label: "Einsatz gesamt", value: fmtS(game.s.wagered + game.s.virtWagered))
            StatCell(label: "Gesamtgewinne", value: fmtS(game.s.wonTotal))
            StatCell(label: "Größter Gewinn", value: fmtS(game.s.biggestWin))
            StatCell(label: "ARENA-Liga-Wetten", value: "\(game.s.virtBets)")
            StatCell(label: "Tages-Tipp-Bestserie", value: "\(game.s.pickBest) 🔥")
            StatCell(label: "Freispiele genutzt", value: fmt(game.s.spins))
            StatCell(label: "Bonus-Claims", value: "\(game.s.claims)")
            StatCell(label: "Sammelkarten", value: "\(game.s.cards) / 135")
        }
    }

    private var stadiumCard: some View {
        Card {
            ForEach(STADIUM_PARTS) { part in
                let lvl = game.stadiumLevel(part.id)
                HStack(spacing: 10) {
                    Text(part.icon)
                        .font(.system(size: 16))
                        .frame(width: 34, height: 34)
                        .background(Theme.card2)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(part.name) · Stufe \(lvl)\(lvl >= STADIUM_MAX_LEVEL ? " (max)" : "")")
                            .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                        HStack(spacing: 3) {
                            ForEach(0..<STADIUM_MAX_LEVEL, id: \.self) { i in
                                Capsule()
                                    .fill(i < lvl
                                          ? AnyShapeStyle(LinearGradient(colors: [Theme.goldDeep, Theme.gold2], startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(Color.white.opacity(0.08)))
                                    .frame(width: 14, height: 5)
                            }
                        }
                    }
                    Spacer()
                    if lvl < STADIUM_MAX_LEVEL {
                        Button {
                            game.upgradeStadium(part.id)
                        } label: {
                            VStack(spacing: 1) {
                                Text("Ausbauen").font(.system(size: 9.5, weight: .heavy))
                                Text(fmtS(stadiumCost(level: lvl))).font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                            }
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            HStack(spacing: 6) {
                Text("⚡ Effekt: +\(String(format: "%.1f", 1.5 * Double(game.stadiumTotal)).replacingOccurrences(of: ".", with: ",")) % auf den Arena Bonus")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.gold2)
                Spacer()
                Text("max +30 %")
                    .font(.system(size: 9)).foregroundStyle(Theme.dim)
            }
            Text("Ausbau kostet Coins, gibt XP, Status — und boostet deinen Arena Bonus. Bewusst kein Quotenboost: Quoten bleiben für alle fair.")
                .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
        }
    }

    private var badges: [(String, String, Bool)] {
        [
            ("⚽", "Erster Tipp", game.s.betsPlaced > 0),
            ("🎯", "Serie 3 im Tages-Tipp", game.s.pickBest >= 3),
            ("🏟", "Liga-Wetter", game.s.virtBets > 0),
            ("🔥", "7-Tage-Serie", game.s.streak >= 7),
            ("🎡", "Bonus-Rad", game.s.claims >= 3),
            ("🏗", "Baumeister", game.stadiumTotal >= 5),
        ]
    }

    private var badgesCard: some View {
        Card {
            HStack(spacing: 8) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    VStack(spacing: 4) {
                        Text(badge.0)
                            .font(.system(size: 18))
                            .frame(width: 42, height: 42)
                            .background(Theme.card2)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
                            .opacity(badge.2 ? 1 : 0.3)
                        Text(badge.1)
                            .font(.system(size: 7.5)).foregroundStyle(Theme.mut)
                            .multilineTextAlignment(.center)
                            .frame(width: 48)
                    }
                }
            }
        }
    }

    // Demo-Shop: bewusst dezent (Engagement-Modus) — im Produkt Apple IAP mit Kauf-Limits
    private var shopCard: some View {
        Card {
            ForEach(Array(SHOP_PACKS.enumerated()), id: \.offset) { i, pack in
                HStack(spacing: 8) {
                    Text("🪙").font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pack.title).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                        Text("+\(fmtS(pack.coins)) Coins").font(.system(size: 9.5).monospacedDigit()).foregroundStyle(Theme.mut)
                    }
                    Spacer()
                    Button {
                        game.buyPack(i)
                    } label: {
                        Text(pack.price)
                            .font(.system(size: 10.5, weight: .heavy).monospacedDigit())
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
            Text("Demo-Käufe ohne echtes Geld (Produkt: Apple IAP, 15–30 % Kommission). Freispiele und Gewinnchancen sind grundsätzlich nicht käuflich.")
                .font(.system(size: 9)).foregroundStyle(Theme.dim)
        }
    }

    private var rgCard: some View {
        Card {
            Text("ARENA ist ein reines Unterhaltungsangebot (18+).")
                .font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.text)
            Text("Coins haben keinen Geldwert und können nicht ausgezahlt werden. In der App verfügbar: Kauf-Limits, Erinnerungen an die Spielzeit, Spielpausen und Selbstausschluss. Hilfe & Beratung: check-dein-spiel.de · Im POC angedeutet, im Produkt verpflichtend.")
                .font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
    }
}
