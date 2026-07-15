import SwiftUI

struct BetSlipView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule().fill(Theme.line).frame(width: 40, height: 4).frame(maxWidth: .infinity)
            HStack {
                Text(game.slip.count > 1 ? "Kombiwette (\(game.slip.count)er)" : "Einzelwette")
                    .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.text)
                Spacer()
                Button {
                    game.showSlip = false
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.dim)
                }
            }

            if game.slip.isEmpty {
                Text("Keine Auswahl.").font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                ForEach(game.slip) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                            Text(item.sub).font(.system(size: 9.5)).foregroundStyle(Theme.mut)
                        }
                        Spacer()
                        Text(fmtOdd(item.odds))
                            .font(.system(size: 12.5, weight: .black).monospacedDigit())
                            .foregroundStyle(Theme.gold2)
                        Button {
                            game.toggleSelect(item)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.dim)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }

            StakeSlider(stake: $game.stake)

            summaryRow("Gesamtquote", game.slip.isEmpty ? "–" : fmtOdd(game.slipTotalOdds))
            summaryRow("Einsatz", fmtS(game.stake))
            HStack {
                Text("Möglicher Gewinn").font(.system(size: 11)).foregroundStyle(Theme.mut)
                Spacer()
                Text(game.slip.isEmpty ? "–" : fmtS(Int(Double(game.stake) * game.slipTotalOdds)))
                    .font(.system(size: 13.5, weight: .black).monospacedDigit())
                    .foregroundStyle(Theme.green)
            }

            Button {
                game.placeBet()
            } label: {
                Text("Tipp platzieren")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(red: 0.01, green: 0.19, blue: 0.1))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [Color(red: 0.44, green: 0.94, blue: 0.69), Theme.green, Color(red: 0.11, green: 0.66, blue: 0.39)], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(game.slip.isEmpty)
            .opacity(game.slip.isEmpty ? 0.5 : 1)

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.mut)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.text)
        }
    }
}

// MARK: - Dynamischer Einsatz: Slider, Maximum am Spielerlevel gecapt

struct StakeSlider: View {
    @EnvironmentObject var game: GameState
    @Binding var stake: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Einsatz")
                    .font(.system(size: 10, weight: .heavy)).kerning(1)
                    .foregroundStyle(Theme.dim)
                    .textCase(.uppercase)
                Spacer()
                Text(fmtS(stake))
                    .font(.system(size: 15, weight: .black).monospacedDigit())
                    .foregroundStyle(Theme.gold2)
                Button("Max") { stake = game.maxStake }
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.card2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
            Slider(
                value: Binding(
                    get: { Double(min(stake, game.maxStake)) },
                    set: { stake = max(game.minStake, Int(($0 / Double(game.stakeStep)).rounded()) * game.stakeStep) }
                ),
                in: Double(game.minStake)...Double(max(game.maxStake, game.minStake + game.stakeStep)),
                step: Double(game.stakeStep)
            )
            .tint(Theme.gold)
            HStack {
                Text(fmtS(game.minStake)).font(.system(size: 9).monospacedDigit()).foregroundStyle(Theme.dim)
                Spacer()
                Text("Max \(fmtS(game.maxStake)) · steigt mit deinem Level (\(game.level))")
                    .font(.system(size: 9)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.vertical, 4)
        .onAppear { if stake > game.maxStake { stake = game.maxStake } }
    }
}
