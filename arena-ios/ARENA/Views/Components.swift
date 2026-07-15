import SwiftUI

// MARK: - Karte

struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                LinearGradient(colors: [Theme.card2, Theme.card], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Zwei-Spalten-Layout (Landscape)

struct TwoCol<L: View, R: View>: View {
    @ViewBuilder var left: () -> L
    @ViewBuilder var right: () -> R
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10, content: left)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10, content: right)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Abschnitts-Kopf

struct SectionHeader: View {
    let title: String
    var detail: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .heavy))
                .kerning(1.6)
                .foregroundStyle(Theme.mut)
            Spacer()
            if !detail.isEmpty {
                Text(detail).font(.system(size: 10)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
    }
}

// MARK: - Quoten-Button

struct OddButton: View {
    let label: String
    let odds: Double
    let selected: Bool
    var disabled: Bool = false
    var drift: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.mut)
                HStack(spacing: 2) {
                    Text(fmtOdd(odds))
                        .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(selected ? Color(red: 0.24, green: 0.16, blue: 0) : Theme.text)
                    if drift > 0 { Text("▲").font(.system(size: 7)).foregroundStyle(Theme.green) }
                    if drift < 0 { Text("▼").font(.system(size: 7)).foregroundStyle(Theme.red) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selected
                    ? AnyShapeStyle(LinearGradient(colors: [Theme.gold2, Theme.gold], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Theme.card2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Theme.goldDeep : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Fortschrittsbalken

struct ProgressBar: View {
    let value: Double   // 0...1
    var green = false
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.4))
                Capsule()
                    .fill(LinearGradient(
                        colors: green ? [Theme.green.opacity(0.7), Theme.green] : [Theme.goldDeep, Theme.gold2],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Team-Logo (ARENA Liga)

struct TeamBadge: View {
    let team: VTeam
    var size: CGFloat = 22
    var body: some View {
        Circle()
            .fill(team.color)
            .frame(width: size, height: size)
            .overlay(
                Text(team.initials)
                    .font(.system(size: size * 0.38, weight: .heavy))
                    .foregroundStyle(Theme.bg)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Stat-Kachel

struct StatCell: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy)).kerning(1)
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Gesperrte Feature-Karte

struct LockedCard: View {
    let icon: String
    let title: String
    let text: String
    var body: some View {
        Card {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 17))
                    .frame(width: 38, height: 38)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                    Text(text).font(.system(size: 10)).foregroundStyle(Theme.mut)
                }
            }
        }
    }
}
