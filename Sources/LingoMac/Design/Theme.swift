import SwiftUI

/// Токены DESIGN.md один в один (§1–§4). Значений, которых нет в DESIGN.md, здесь нет.
/// Тема только тёмная (DESIGN.md: «Тема: только тёмная в v1»).
enum Theme {
    // MARK: §1 Цвета
    enum C {
        static let bgWindow = Color(hex: 0x121619)
        static let bgSidebar = Color(hex: 0x14181B)
        static let bgHints = Color(hex: 0x161A1E)
        static let bgTitlebar = Color(hex: 0x1B2125)
        static let surfaceCard = Color(hex: 0x1F252A)
        static let surfaceVoicePanel = Color(hex: 0x171D22)
        static let surfaceInput = Color(hex: 0x181F21)
        static let surfaceBubbleAssistant = Color(hex: 0x242E38)
        static let surfaceRowSelected = Color(hex: 0x232C39)
        static let surfaceControl = Color(hex: 0x283039)
        static let surfaceSendButton = Color(hex: 0x333D47)
        static let surfaceChip = Color(hex: 0x101719)
        static let borderSubtle = Color(hex: 0x23292E)
        static let borderDivider = Color(hex: 0x272B2E)
        static let accentPrimary = Color(hex: 0x1162F4)
        static let bubbleUser = Color(hex: 0x105DEB)
        static let avatarUserBg = Color(hex: 0x1B324F)
        static let avatarUserIcon = Color(hex: 0x4075D1)
        static let avatarBotBg = Color(hex: 0x274246)
        static let avatarBotIcon = Color(hex: 0x87EBE0)
        static let voiceAccent = Color(hex: 0x5BF2DF)
        static let voiceAccentSoft = Color(hex: 0x1C433F)
        static let statusDanger = Color(hex: 0xE64542)
        static let statusSuccess = Color(hex: 0x1FD67F)
        static let textPrimary = Color(hex: 0xFFFFFF)
        static let textSecondary = Color(hex: 0xAAB3BF)
        static let textTertiary = Color(hex: 0x848B97)
        static let textMetaOnAccent = Color(hex: 0xAFE8FF)
        static let iconSend = Color(hex: 0xE7EFF8)
    }

    // MARK: §2 Типографика (SF Pro, размеры в pt)
    enum F {
        static let logo = Font.system(size: 30, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let subtitle = Font.system(size: 14, weight: .regular)
        static let button = Font.system(size: 16, weight: .medium)
        static let segment = Font.system(size: 14, weight: .medium)
        static let section = Font.system(size: 13, weight: .regular)
        static let rowTitle = Font.system(size: 14, weight: .regular)
        static let rowMeta = Font.system(size: 12, weight: .regular)
        static let bubble = Font.system(size: 17, weight: .regular)
        static let meta = Font.system(size: 11, weight: .regular)
        static let panelTitle = Font.system(size: 17, weight: .semibold)
        static let hintPhrase = Font.system(size: 16, weight: .semibold)
        static let hintTranslation = Font.system(size: 13, weight: .regular)
        static let voiceState = Font.system(size: 16, weight: .semibold)
        static let caption = Font.system(size: 11, weight: .regular)
        static let chip = Font.system(size: 13, weight: .regular)
    }

    // MARK: §3 Отступы и сетка (шаг 4 pt: 4, 8, 12, 16, 20, 24, 32)
    enum S {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32

        static let sidebarWidth: CGFloat = 256
        static let hintsWidth: CGFloat = 264
        static let headerHeight: CGFloat = 72
        static let columnPadding: CGFloat = 16
        static let messageGap: CGFloat = 16
        static let bubblePaddingH: CGFloat = 16
        static let bubblePaddingV: CGFloat = 12
        static let avatarGap: CGFloat = 12
        static let rowPadding: CGFloat = 12
        static let cardGap: CGFloat = 12
        /// Ширина пузыря — не больше 70% центральной колонки.
        static let bubbleMaxFraction: CGFloat = 0.7
        /// R-40: при ширине окна меньше 1280 правая колонка сворачивается.
        static let hintsCollapseWidth: CGFloat = 1280
        /// R-40: минимальный размер окна.
        static let minWindow = CGSize(width: 1100, height: 700)
    }

    // MARK: §4 Радиусы и размеры
    enum R {
        static let button: CGFloat = 8
        static let bubble: CGFloat = 16
        static let card: CGFloat = 10

        static let primaryButtonHeight: CGFloat = 40
        static let segmentHeight: CGFloat = 36
        static let rowHeight: CGFloat = 50
        static let avatar: CGFloat = 40
        static let voicePanelHeight: CGFloat = 86
        static let micCircle: CGFloat = 50
        static let roundButton: CGFloat = 44
        static let inputHeight: CGFloat = 48
        static let sendButton: CGFloat = 40
        static let hintCardMinHeight: CGFloat = 78
        static let chipHeight: CGFloat = 32
        static let stroke: CGFloat = 1
        /// Добавлено в DESIGN.md §4 (P-01): столбик волны и промежуток.
        static let waveBar: CGFloat = 3
        static let waveGap: CGFloat = 4
        /// Добавлено в DESIGN.md §4 (P-01): точка статуса в плашке источника.
        static let statusDot: CGFloat = 12
    }

    // MARK: §6 Состояния
    static let hoverOpacity: Double = 0.85
    static let disabledOpacity: Double = 0.4
    /// §5: наведение на строку сессии — фон выбранной с прозрачностью 50%.
    static let rowHoverOpacity: Double = 0.5
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Обводка `stroke.subtle` (1 pt, `border.subtle`).
extension View {
    func subtleStroke<S: InsettableShape>(_ shape: S) -> some View {
        overlay(shape.strokeBorder(Theme.C.borderSubtle, lineWidth: Theme.R.stroke))
    }
}
