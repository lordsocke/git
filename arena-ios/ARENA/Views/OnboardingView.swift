import SwiftUI

// MARK: - FTUE: Willkommen → 18+ → Konto (Apple-Demo/Gast) → Mitteilungen

struct OnboardingView: View {
    @EnvironmentObject var game: GameState
    @State private var step = 0
    @State private var ageOK = false
    @State private var name = ""
    @State private var avatar = "⚽️"
    @State private var viaApple = false

    private let avatars = ["⚽️", "🦁", "🔥", "👑", "🎯", "🛡"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(colors: [Color(red: 0.14, green: 0.19, blue: 0.42).opacity(0.6), .clear],
                           center: .top, startRadius: 20, endRadius: 500)
                .ignoresSafeArea()

            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ARENA")
                        .font(.system(size: 44, weight: .black)).kerning(2)
                        .foregroundStyle(LinearGradient(colors: [Theme.gold2, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                    Text("Tippen. Liga. Teamgeist.\nOhne echtes Geld zu riskieren.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Nur virtuelle Coins · keine Auszahlung · 18+")
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Theme.gold : Theme.line)
                                .frame(width: i == step ? 26 : 12, height: 5)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(width: 280, alignment: .leading)

                Group {
                    switch step {
                    case 0: agePage
                    case 1: accountPage
                    default: pushPage
                    }
                }
                .frame(width: 330)
            }
            .padding(24)
        }
    }

    // Schritt 1: 18+-Selbstauskunft (echte Altersverifikation: Gutachtensfrage)
    private var agePage: some View {
        Card {
            Text("Bevor es losgeht").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.text)
            Text("ARENA enthält simuliertes Glücksspiel und Sportwetten mit virtueller Währung. Die App ist ausschließlich für Erwachsene.")
                .font(.system(size: 11)).foregroundStyle(Theme.mut)
            Button {
                ageOK.toggle()
                Haptics.light()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ageOK ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18)).foregroundStyle(ageOK ? Theme.green : Theme.dim)
                    Text("Ich bestätige, dass ich mindestens 18 Jahre alt bin.")
                        .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Hilfe bei Glücksspielproblemen: check-dein-spiel.de")
                .font(.system(size: 9)).foregroundStyle(Theme.dim)
            primaryButton("Weiter", enabled: ageOK) { step = 1 }
        }
    }

    // Schritt 2: Konto — Apple (Demo-Stub) oder Gast, Name + Avatar
    private var accountPage: some View {
        Card {
            Text("Dein Profil").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                ForEach(avatars, id: \.self) { a in
                    Button {
                        avatar = a
                        Haptics.light()
                    } label: {
                        Text(a).font(.system(size: 20))
                            .frame(width: 40, height: 40)
                            .background(avatar == a ? Theme.gold.opacity(0.22) : Theme.card2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(avatar == a ? Theme.gold : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Dein Name", text: $name)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            Button {
                viaApple = true
                step = 2
            } label: {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Mit Apple anmelden").font(.system(size: 13, weight: .heavy))
                    Text("(Demo)").font(.system(size: 10)).opacity(0.6)
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            Button {
                viaApple = false
                step = 2
            } label: {
                Text("Als Gast weiterspielen")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Text("Gast-Fortschritt bleibt auf diesem Gerät — verknüpfen jederzeit in den Einstellungen.")
                .font(.system(size: 9)).foregroundStyle(Theme.dim)
        }
    }

    // Schritt 3: Mitteilungen (echte Systemanfrage) → fertig
    private var pushPage: some View {
        Card {
            Text("Nichts verpassen").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.text)
            Text("Wir sagen dir, wenn dein Arena Bonus bereit ist — mehr Push gibt es nicht ohne dein Okay.")
                .font(.system(size: 11)).foregroundStyle(Theme.mut)
            primaryButton("Mitteilungen aktivieren", enabled: true) {
                game.completeOnboarding(name: name, avatar: avatar, apple: viaApple)
                game.requestPushPermission()
            }
            Button {
                game.completeOnboarding(name: name, avatar: avatar, apple: viaApple)
            } label: {
                Text("Später").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            Text("Danach wählst du im Sport-Tab deine Start-Liga. 🏁")
                .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
