import SwiftUI

// MARK: - Bonus-Claim-Overlay (Belohnung ist bereits gutgeschrieben — reine Zelebration)

struct BonusClaimOverlay: View {
    @EnvironmentObject var game: GameState
    let amount: Int
    let special: Bool

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.85).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(special ? "ARENA BONUS + SPECIAL!" : "ARENA BONUS")
                    .font(.system(size: 11, weight: .heavy)).kerning(2.4)
                    .foregroundStyle(Theme.gold2)
                Text("+\(fmtS(amount))")
                    .font(.system(size: 30, weight: .black).monospacedDigit())
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.79), Theme.gold2, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.55), radius: 16, y: 4)
                Text("+ 2 Freispiele für Arena Spins 🎁")
                    .font(.system(size: 11)).foregroundStyle(Theme.mut)
                if special {
                    Text("Ring voll — gleich dreht das Bonus-Rad!")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold2)
                }
                Button {
                    game.dismissBonus(thenWheel: special)
                } label: {
                    Text("Abholen")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .padding(.top, 6)
                if !special {
                    HStack(spacing: 8) {
                        Button("🎰 Freispiele nutzen") {
                            game.dismissBonus(thenWheel: false)
                            game.showSlot = true
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
            }
            .padding(30)
        }
        .transition(.opacity)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .heavy))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.card2)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Bonus-Rad

struct WheelOverlay: View {
    @EnvironmentObject var game: GameState
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var resultMsg: String?
    @State private var pendingSegment: WheelSegment?

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.88).ignoresSafeArea()
            HStack(spacing: 30) {
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Theme.gold2)
                        .frame(width: 20, height: 16)
                        .shadow(radius: 3)
                        .zIndex(2)
                        .offset(y: 6)
                    WheelShapeView()
                        .frame(width: 230, height: 230)
                        .rotationEffect(.degrees(rotation))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("SPECIAL BONUS · BONUS-RAD")
                        .font(.system(size: 11, weight: .heavy)).kerning(2.4)
                        .foregroundStyle(Theme.gold2)
                    Text("Dein 3. Claim — das Rad kommt zusätzlich zum Bonus. Coins-Multiplikatoren, Freispiele, Sammelkarten oder der Jackpot.")
                        .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                    if let msg = resultMsg {
                        Text(msg)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.gold2)
                    }
                    Button {
                        if let seg = pendingSegment, !spinning {
                            game.showWheel = false
                            if seg.freeSpins != nil { game.showSlot = true }
                        } else if !spinning {
                            spin()
                        }
                    } label: {
                        Text(pendingSegment != nil && !spinning ? (pendingSegment?.freeSpins != nil ? "Jetzt spielen!" : "Super!") : "Drehen!")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .opacity(spinning ? 0.5 : 1)
                    }
                    .disabled(spinning)
                }
                .frame(width: 250)
            }
            .padding(24)
        }
        .transition(.opacity)
    }

    private func spin() {
        spinning = true
        resultMsg = nil
        let seg = game.drawWheelSegment()
        pendingSegment = seg
        let segAngle = 360.0 / Double(WHEEL_SEGMENTS.count)
        let target = 5 * 360 + (360 - (Double(seg.id) * segAngle + segAngle / 2)) - rotation.truncatingRemainder(dividingBy: 360)
        withAnimation(.timingCurve(0.12, 0.6, 0.08, 1, duration: 4.2)) {
            rotation += target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            resultMsg = game.applyWheel(seg)
            spinning = false
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct WheelShapeView: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.055, green: 0.075, blue: 0.19))
            Circle().stroke(Theme.gold, lineWidth: 4)
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let r = geo.size.width / 2 - 6
                let segAngle = 360.0 / Double(WHEEL_SEGMENTS.count)
                ZStack {
                    ForEach(WHEEL_SEGMENTS) { seg in
                        let start = Angle(degrees: Double(seg.id) * segAngle - 90)
                        let end = Angle(degrees: Double(seg.id + 1) * segAngle - 90)
                        Path { p in
                            p.move(to: c)
                            p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
                            p.closeSubpath()
                        }
                        .fill(seg.color)
                        .overlay(
                            Path { p in
                                p.move(to: c)
                                p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
                                p.closeSubpath()
                            }.stroke(Theme.bg, lineWidth: 2)
                        )
                        let mid = (Double(seg.id) + 0.5) * segAngle - 90
                        let tx = c.x + r * 0.62 * cos(mid * .pi / 180)
                        let ty = c.y + r * 0.62 * sin(mid * .pi / 180)
                        Text(seg.label)
                            .font(.system(size: seg.label.count > 6 ? 8 : 12.5, weight: .heavy))
                            .foregroundStyle(seg.coinMult == 50 ? Color(red: 1, green: 0.91, blue: 0.66) : Theme.text)
                            .rotationEffect(.degrees(mid + 90))
                            .position(x: tx, y: ty)
                    }
                    Circle().fill(Theme.gold).frame(width: 42, height: 42).position(c)
                    Text("ARENA").font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0)).position(c)
                }
            }
        }
    }
}

// MARK: - Big Win

struct BigWinOverlay: View {
    @EnvironmentObject var game: GameState
    let title: String
    let amount: Int

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.85).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 34, weight: .black)).kerning(1)
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.79), Theme.gold2, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.55), radius: 22, y: 4)
                Text("+\(fmt(amount)) Coins")
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                    .foregroundStyle(.white)
                Button {
                    game.bigWin = nil
                } label: {
                    Text("Einsammeln")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0))
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(LinearGradient(colors: [Theme.gold2, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .padding(.top, 8)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}
