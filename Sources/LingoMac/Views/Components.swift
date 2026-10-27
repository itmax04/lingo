import SwiftUI

/// Abstract assistant identity; user messages do not use human portraits.
struct Avatar: View {
    let role: AvatarRole
    var speaking = false
    enum AvatarRole { case user, bot }
    var body: some View {
        Group {
            if role == .bot { LingoMark(speaking: speaking) }
            else { Image(systemName: "person.crop.circle").foregroundStyle(Theme.C.textSecondary) }
        }
        .frame(width: Theme.R.avatar, height: Theme.R.avatar)
        .accessibilityHidden(true)
    }
}

/// ✓ — saved locally, ✓✓ — written to the sync folder (R-38).
struct DeliveryTicks: View {
    let synced: Bool
    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
            if synced { Image(systemName: "checkmark") }
        }
        .font(.system(size: 9, weight: .semibold))
        .accessibilityLabel(synced ? "Written to the sync folder" : "Saved locally")
    }
}

/// Pointer feedback and an explicit keyboard focus outline use DESIGN.md v2 tokens.
struct LingoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverWrapper(pressed: configuration.isPressed) { configuration.label }
    }

    private struct HoverWrapper<Content: View>: View {
        let pressed: Bool
        @ViewBuilder let content: () -> Content
        @State private var hover = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            content()
                .opacity(enabled ? ((hover || pressed) ? Theme.hoverOpacity : 1) : Theme.disabledOpacity)
                .onHover { hover = $0 }
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.R.button)
                        .strokeBorder(focused ? Theme.C.accentPrimary : .clear, lineWidth: 2)
                        .padding(-4).allowsHitTesting(false).accessibilityHidden(true)
                }
        }
    }
}

/// Round button with a caption (Pause, Finish — DESIGN.md §5, size.roundButton).
struct RoundCaptionButton: View {
    let symbol: String
    let caption: LocalizedStringKey
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

/// Vertical or horizontal column divider `border.divider`.
struct ColumnDivider: View {
    var vertical = true
    var body: some View {
        Rectangle()
            .fill(Theme.C.borderDivider)
            .frame(width: vertical ? Theme.R.stroke : nil, height: vertical ? nil : Theme.R.stroke)
    }
}
