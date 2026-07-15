import SwiftUI

// MARK: - Einstellungen: Konto · Mitteilungen · Spiel · Spielerschutz · Käufe · Rechtliches

struct SettingsView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Capsule().fill(Theme.line).frame(width: 40, height: 4).frame(maxWidth: .infinity)
                HStack {
                    Text("Einstellungen").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.text)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.dim)
                    }
                }

                SectionHeader(title: "Konto")
                Card {
                    HStack(spacing: 10) {
                        Text(game.s.avatar).font(.system(size: 22))
                        TextField("Name", text: $name)
                            .font(.system(size: 13, weight: .bold))
                            .onSubmit {
                                game.s.playerName = name.isEmpty ? game.s.playerName : name
                                game.save()
                                game.toast("Name gespeichert.")
                            }
                        Spacer()
                        Text(game.s.appleLinked ? " verknüpft" : "Gast")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(game.s.appleLinked ? Theme.green : Theme.mut)
                    }
                    if !game.s.appleLinked {
                        Button {
                            game.s.appleLinked = true
                            game.save()
                            game.toast("✅ Mit Apple verknüpft (Demo) — Fortschritt gerätesicher.")
                        } label: {
                            HStack { Image(systemName: "applelogo"); Text("Mit Apple verknüpfen (Demo)").font(.system(size: 12, weight: .heavy)) }
                                .foregroundStyle(Theme.bg)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionHeader(title: "Mitteilungen & Spiel")
                Card {
                    Toggle(isOn: Binding(
                        get: { game.s.notifBonus },
                        set: { on in
                            if on { game.requestPushPermission() }
                            else {
                                game.s.notifBonus = false
                                game.scheduleBonusNotification()
                                game.save()
                            }
                        })) {
                        settingLabel("🔔", "Bonus-Erinnerung", "Push, wenn der 3h-Bonus bereit ist")
                    }
                    .tint(Theme.gold)
                    Toggle(isOn: Binding(get: { game.s.hapticsOn }, set: { game.setHaptics($0) })) {
                        settingLabel("📳", "Haptik", "Vibrations-Feedback bei Toren & Gewinnen")
                    }
                    .tint(Theme.gold)
                }

                SectionHeader(title: "Spielerschutz", detail: "im Produkt verbindlich")
                Card {
                    settingLabel("⏱", "Reality-Check", "Erinnerung an die Spielzeit")
                    Picker("Reality-Check", selection: Binding(
                        get: { game.s.rgCheckMins },
                        set: { game.s.rgCheckMins = $0; game.save() })) {
                        Text("15 Min").tag(15)
                        Text("30 Min").tag(30)
                        Text("60 Min").tag(60)
                    }
                    .pickerStyle(.segmented)
                    Button {
                        game.startPause(hours: 24)
                    } label: {
                        Text("🛑 24 Stunden Spielpause starten")
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.red)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Theme.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    Text("Selbstausschluss, Kauf-Limits und Verlaufs-Transparenz sind im Produkt Teil der RG-Suite (Konzept Kap. 18). Hilfe: check-dein-spiel.de")
                        .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                }

                SectionHeader(title: "Kaufhistorie", detail: "Demo-Käufe")
                Card {
                    if game.s.purchases.isEmpty {
                        Text("Noch keine Käufe.").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    } else {
                        ForEach(game.s.purchases.reversed()) { p in
                            HStack {
                                Text("🧾 \(p.title)").font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.text)
                                Spacer()
                                Text("+\(fmtS(p.coins))").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.gold2)
                                Text(p.price).font(.system(size: 11, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.mut)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                SectionHeader(title: "Rechtliches & App")
                Card {
                    legalRow("Datenschutzerklärung (Platzhalter)")
                    legalRow("Impressum (Platzhalter)")
                    legalRow("Barrierefreiheit: VoiceOver/Kontraste in Arbeit (BFSG)")
                    HStack {
                        Text("Version").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                        Spacer()
                        Text("0.3 (POC) · Landscape").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.dim)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { name = game.s.playerName }
    }

    private func settingLabel(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 8) {
            Text(icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 9.5)).foregroundStyle(Theme.mut)
            }
        }
    }

    private func legalRow(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Spielpause-Sperre (Vollbild, blockierend)

struct PauseOverlay: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.97).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("🛑").font(.system(size: 40))
                Text("Spielpause aktiv").font(.system(size: 17, weight: .black)).foregroundStyle(Theme.text)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Noch \(remainingText) — gönn dir die Auszeit.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Text("Hilfe & Beratung: check-dein-spiel.de")
                    .font(.system(size: 10)).foregroundStyle(Theme.dim)
                Button {
                    game.endPauseDemo()
                } label: {
                    Text("Demo: Pause aufheben")
                        .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.card2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private var remainingText: String {
        let secs = Int(max(0, (game.s.rgPausedUntil ?? Date()).timeIntervalSinceNow))
        return "\(secs / 3600) Std \(secs % 3600 / 60) Min"
    }
}
