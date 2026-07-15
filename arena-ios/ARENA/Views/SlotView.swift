import SwiftUI
import SpriteKit

// MARK: - Arena Spins: SpriteKit-Minigame (nur Freispiele, kein Coin-Einsatz)

struct SlotView: View {
    @EnvironmentObject var game: GameState
    @State private var scene = SlotScene(size: CGSize(width: 320, height: 320))
    @State private var spinning = false
    @State private var message = "Viel Glück!"

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.16).ignoresSafeArea()
            HStack(spacing: 26) {
                SpriteView(scene: scene)
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold2.opacity(0.25), lineWidth: 2))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Arena Spins")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.text)

                    Text("Bonus-Minispiel — kein Coin-Einsatz möglich. Freispiele gibt es aus dem Arena Bonus, dem Bonus-Rad, Challenges und Level-Ups. Jedes Freispiel gibt Fest-XP.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.mut)

                    HStack(spacing: 6) {
                        Text("🎁")
                        Text("\(game.s.freeSpins) \(game.s.freeSpins == 1 ? "Freispiel" : "Freispiele")")
                            .font(.system(size: 11.5, weight: .heavy).monospacedDigit())
                    }
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.green.opacity(0.35), lineWidth: 1))

                    Button {
                        spin()
                    } label: {
                        Text("FREISPIEL DREHEN")
                            .font(.system(size: 13.5, weight: .heavy)).kerning(1)
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .opacity(spinning || game.s.freeSpins <= 0 ? 0.45 : 1)
                    }
                    .disabled(spinning || game.s.freeSpins <= 0)

                    Text(game.s.freeSpins <= 0 && !spinning ? "Keine Freispiele — hol dir den nächsten Bonus!" : message)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Theme.gold2)
                        .frame(minHeight: 18)
                }
                .frame(width: 280)
            }
            .padding(24)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        game.showSlot = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 34, height: 34)
                            .background(Theme.card2)
                            .clipShape(Circle())
                    }
                    .padding(16)
                }
                Spacer()
            }

            // Big-Win + Toasts müssen IM Cover gerendert werden — das RootView-Overlay
            // liegt unter dem fullScreenCover und wäre sonst unsichtbar.
            if let win = game.bigWin {
                BigWinOverlay(title: win.title, amount: win.amount)
            }
            if let toast = game.toastText {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 11.5, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 15).padding(.vertical, 9)
                        .background(Color(red: 0.11, green: 0.15, blue: 0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
                        .padding(.bottom, 18)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func spin() {
        guard let outcome = game.playSpin() else { return }
        spinning = true
        message = "…"
        Haptics.light()
        scene.spin(to: outcome.grid) {
            spinning = false
            if outcome.win > 0 {
                message = "Gewinn: +\(fmt(outcome.win)) Coins"
            } else {
                message = "Kein Treffer — XP gab es trotzdem"
            }
            game.celebrateSpin(outcome)
        }
    }
}

// MARK: - SpriteKit-Szene: 3×3-Walzen mit Emoji-Symbolen

final class SlotScene: SKScene {
    private var labels: [[SKLabelNode]] = []   // [spalte][zeile]
    private var flickerTimers: [Timer] = []

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = UIColor(red: 0.06, green: 0.05, blue: 0.14, alpha: 1)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    private func setup() {
        let cell = size.width / 3
        for c in 0..<3 {
            var col: [SKLabelNode] = []
            for r in 0..<3 {
                let label = SKLabelNode(text: SlotMath.symbols[(c + r) % SlotMath.symbols.count])
                label.fontSize = cell * 0.62
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(
                    x: cell * (CGFloat(c) + 0.5),
                    y: size.height - cell * (CGFloat(r) + 0.5) - (size.height - cell * 3) / 2
                )
                addChild(label)
                col.append(label)
            }
            labels.append(col)

            if c > 0 {
                let line = SKShapeNode(rect: CGRect(x: cell * CGFloat(c) - 0.5, y: 8, width: 1, height: size.height - 16))
                line.fillColor = UIColor(red: 0.96, green: 0.83, blue: 0.47, alpha: 0.15)
                line.strokeColor = .clear
                addChild(line)
            }
        }
    }

    /// Ergebnis steht VOR der Animation fest — wie beim Server-RNG.
    func spin(to grid: [[Int]], completion: @escaping () -> Void) {
        flickerTimers.forEach { $0.invalidate() }
        flickerTimers = []
        let durations: [TimeInterval] = [0.9, 1.2, 1.5]
        for c in 0..<3 {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                guard let self else { return }
                for r in 0..<3 {
                    self.labels[c][r].text = SlotMath.symbols[SlotMath.roll()]
                }
            }
            flickerTimers.append(timer)
            DispatchQueue.main.asyncAfter(deadline: .now() + durations[c]) { [weak self] in
                guard let self else { return }
                if self.flickerTimers.indices.contains(c) { self.flickerTimers[c].invalidate() }
                for r in 0..<3 {
                    self.labels[c][r].text = SlotMath.symbols[grid[c][r]]
                    self.labels[c][r].run(.sequence([
                        .scale(to: 1.25, duration: 0.08),
                        .scale(to: 1.0, duration: 0.12),
                    ]))
                }
                Haptics.light()
                if c == 2 { completion() }
            }
        }
    }
}
