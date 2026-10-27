import AppKit
import LingoCore
import SwiftUI

/// Quiet, DESIGN.md v2. Named dynamic colours resolve against the window's appearance.
enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static func accent(_ lang: Lang) -> Color { lang == .en ? C.accentEnglish : C.accentGerman }
    static func accentSurface(_ lang: Lang) -> Color {
        lang == .en ? adaptive(0xE4F2EE, 0x19332F) : adaptive(0xF3E9D9, 0x352A1A)
    }
    enum C {
        static let bgWindow = adaptive(0xF7F6F3, 0x111315)
        static let bgSidebar = adaptive(0xF0EFEB, 0x16191C)
        static let bgHints = adaptive(0xF7F6F3, 0x16191C)
        static let bgTitlebar = bgSidebar
        static let surfaceCard = adaptive(0xFFFFFF, 0x1D2125)
        static let surfaceVoicePanel = surfaceCard
        static let surfaceInput = surfaceCard
        static let surfaceBubbleAssistant = adaptive(0xFFFFFF, 0x20262A)
        static let surfaceRowSelected = adaptive(0xE4E4DE, 0x2B3136)
        static let surfaceControl = adaptive(0xEBECE8, 0x2B3136)
        static let surfaceSendButton = adaptive(0x855107, 0xF2B85B)
        static let surfaceChip = surfaceControl
        static let borderSubtle = adaptive(0xD3D7D9, 0x343A40)
        static let borderDivider = borderSubtle
        static let accentGerman = adaptive(0x855107, 0xF2B85B)
        static let accentEnglish = adaptive(0x136C61, 0x62D5C5)
        static let accentPrimary = accentGerman
        static let bubbleUser = adaptive(0xF3E9D9, 0x29241C)
        static let avatarUserBg = surfaceControl
        static let avatarUserIcon = textSecondary
        static let avatarBotBg = adaptive(0xF3E9D9, 0x352A1A)
        static let avatarBotIcon = accentGerman
        static let voiceAccent = accentGerman
        static let voiceAccentSoft = avatarBotBg
        static let statusDanger = adaptive(0xA52A32, 0xFF9CA2)
        static let statusSuccess = adaptive(0x216A49, 0x86D8AD)
        static let textPrimary = adaptive(0x202428, 0xF5F4F0)
        static let textSecondary = adaptive(0x505A63, 0xB5BBC1)
        static let textTertiary = adaptive(0x59636B, 0x9DA5AC)
        static let textMetaOnAccent = textSecondary
        static let iconSend = adaptive(0xFFFFFF, 0x202428)
        static let accentButtonText = iconSend
    }
    enum F {
        static let logo = Font.system(size: 28, weight: .semibold)
        static let title = Font.system(size: 24, weight: .semibold)
        static let subtitle = Font.system(size: 13)
        static let button = Font.system(size: 14, weight: .medium)
        static let segment = Font.system(size: 13, weight: .medium)
        static let section = Font.system(size: 12, weight: .medium)
        static let rowTitle = Font.system(size: 14)
        static let rowMeta = Font.system(size: 12)
        static let bubble = Font.system(size: 16)
        static let meta = Font.system(size: 12)
        static let panelTitle = Font.system(size: 18, weight: .semibold)
        static let hintPhrase = Font.system(size: 15, weight: .medium)
        static let hintTranslation = Font.system(size: 13)
        static let voiceState = Font.system(size: 14, weight: .medium)
        static let caption = Font.system(size: 12)
        static let chip = Font.system(size: 12, weight: .medium)
    }
    enum S {
        static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16
        static let s20: CGFloat = 20, s24: CGFloat = 24, s32: CGFloat = 32
        static let sidebarWidth: CGFloat = 232, hintsWidth: CGFloat = 272, headerHeight: CGFloat = 80
        static let columnPadding: CGFloat = 16, messageGap: CGFloat = 24
        static let bubblePaddingH: CGFloat = 16, bubblePaddingV: CGFloat = 16
        static let avatarGap: CGFloat = 12, rowPadding: CGFloat = 12, cardGap: CGFloat = 12
        static let bubbleMaxFraction: CGFloat = 0.82, hintsCollapseWidth: CGFloat = 1280
        static let minWindow = CGSize(width: 1100, height: 700)
    }
    enum R {
        static let button: CGFloat = 12, bubble: CGFloat = 16, card: CGFloat = 12
        static let primaryButtonHeight: CGFloat = 44, segmentHeight: CGFloat = 36, rowHeight: CGFloat = 56
        static let avatar: CGFloat = 32, voicePanelHeight: CGFloat = 112, micCircle: CGFloat = 44
        static let roundButton: CGFloat = 36, inputHeight: CGFloat = 48, sendButton: CGFloat = 40
        static let hintCardMinHeight: CGFloat = 100, chipHeight: CGFloat = 28, stroke: CGFloat = 1
        static let waveBar: CGFloat = 2, waveGap: CGFloat = 4, statusDot: CGFloat = 6
    }
    static let hoverOpacity: Double = 0.88, disabledOpacity: Double = 0.5, rowHoverOpacity: Double = 0.55
    static let transitionSeconds: Double = 0.18
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
extension View {
    func subtleStroke<S: InsettableShape>(_ shape: S) -> some View {
        overlay(shape.strokeBorder(Theme.C.borderSubtle, lineWidth: Theme.R.stroke))
    }
}
