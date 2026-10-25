import SwiftUI

/// Круглый аватар 40 pt (DESIGN.md §5).
struct Avatar: View {
    let role: AvatarRole
    enum AvatarRole { case user, bot }

    var body: some View {
        ZStack {
            Circle().fill(role == .user ? Theme.C.avatarUserBg : Theme.C.avatarBotBg)
            switch role {
            case .user:
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.C.avatarUserIcon)
            case .bot:
                RobotIcon()
                    .fill(Theme.C.avatarBotIcon)
                    .frame(width: 20, height: 20)
            }
        }
        .frame(width: Theme.R.avatar, height: Theme.R.avatar)
        .accessibilityHidden(true)
    }
}

/// Иконка робота как на макете (в SF Symbols её нет): голова с антенной, глаза.
struct RobotIcon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        // Антенна.
        p.addEllipse(in: CGRect(x: r.minX + w * 0.43, y: r.minY, width: w * 0.14, height: w * 0.14))
        p.addRect(CGRect(x: r.minX + w * 0.47, y: r.minY + w * 0.1, width: w * 0.06, height: h * 0.14))
        // Уши.
        p.addRoundedRect(in: CGRect(x: r.minX, y: r.minY + h * 0.45, width: w * 0.1, height: h * 0.22), cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        p.addRoundedRect(in: CGRect(x: r.maxX - w * 0.1, y: r.minY + h * 0.45, width: w * 0.1, height: h * 0.22), cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        // Голова с вырезанными глазами (even-odd).
        let head = CGRect(x: r.minX + w * 0.12, y: r.minY + h * 0.24, width: w * 0.76, height: h * 0.66)
        p.addRoundedRect(in: head, cornerSize: CGSize(width: w * 0.2, height: w * 0.2))
        let face = head.insetBy(dx: w * 0.1, dy: h * 0.1)
        p.addRoundedRect(in: face, cornerSize: CGSize(width: w * 0.14, height: w * 0.14))
        p.addEllipse(in: CGRect(x: face.minX + face.width * 0.18, y: face.midY - h * 0.07, width: w * 0.14, height: h * 0.14))
        p.addEllipse(in: CGRect(x: face.maxX - face.width * 0.18 - w * 0.14, y: face.midY - h * 0.07, width: w * 0.14, height: h * 0.14))
        return p
    }

    func fill(_ color: Color) -> some View {
        self.fill(color, style: FillStyle(eoFill: true))
    }
}

/// ✓ — сохранено локально, ✓✓ — записано в папку синхронизации (R-38).
struct DeliveryTicks: View {
    let synced: Bool
    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
            if synced { Image(systemName: "checkmark") }
        }
        .font(.system(size: 9, weight: .semibold))
        .accessibilityLabel(synced ? "Записано в папку синхронизации" : "Сохранено локально")
    }
}

/// Наведение — `opacity(0.85)` поверх исходного, неактивно — `opacity(0.4)` (DESIGN.md §6).
struct LingoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverWrapper(pressed: configuration.isPressed) { configuration.label }
    }

    private struct HoverWrapper<Content: View>: View {
        let pressed: Bool
        @ViewBuilder let content: () -> Content
        @State private var hover = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            content()
                .opacity(enabled ? ((hover || pressed) ? Theme.hoverOpacity : 1) : Theme.disabledOpacity)
                .onHover { hover = $0 }
                .contentShape(Rectangle())
        }
    }
}

/// Круглая кнопка с подписью (Пауза, Завершить — DESIGN.md §5, size.roundButton).
struct RoundCaptionButton: View {
    let symbol: String
    let caption: String
    let fill: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.S.s4) {
                ZStack {
                    Circle().fill(fill)
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: Theme.R.roundButton, height: Theme.R.roundButton)
                Text(caption)
                    .font(Theme.F.caption)
                    .foregroundStyle(Theme.C.textPrimary)
            }
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityLabel(caption)
    }
}

/// Вертикальный или горизонтальный разделитель колонок `border.divider`.
struct ColumnDivider: View {
    var vertical = true
    var body: some View {
        Rectangle()
            .fill(Theme.C.borderDivider)
            .frame(width: vertical ? Theme.R.stroke : nil, height: vertical ? nil : Theme.R.stroke)
    }
}
