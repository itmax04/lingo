import LingoCore
import SwiftUI

/// Voice panel (R-42, DESIGN.md §5): microphone and state, waveform from the sound level, "Pause", "Finish".
struct VoicePanel: View {
    let state: VoiceState
    let levels: [Float]
    var onMic: () -> Void = {}
    var onPause: () -> Void = {}
    var onEnd: () -> Void = {}
    var extraControls: AnyView = AnyView(EmptyView())

    var body: some View {
        HStack(spacing: Theme.S.s16) {
            Button(action: onMic) {
                ZStack {
                    Circle().fill(Theme.C.voiceAccentSoft)
                    Image(systemName: state == .idle ? "mic.fill" : "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.C.voiceAccent)
                }
                .frame(width: Theme.R.micCircle, height: Theme.R.micCircle)
            }
            .buttonStyle(LingoButtonStyle())
            .accessibilityLabel(state == .idle ? "Speak" : "Microphone: \(state.title)")

            Text(state.title)
                .font(Theme.F.voiceState)
                .foregroundStyle(Theme.C.voiceAccent)
                .lineLimit(1)
                .fixedSize()

            Waveform(levels: levels)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.R.micCircle)
                .accessibilityHidden(true)

            extraControls

            RoundCaptionButton(symbol: state == .paused ? "play.fill" : "pause.fill",
                               caption: state == .paused ? "Resume" : "Pause",
                               fill: Theme.C.surfaceControl, iconColor: Theme.C.textPrimary, action: onPause)
            RoundCaptionButton(symbol: "xmark", caption: "Finish",
                               fill: Theme.C.statusDanger, iconColor: Theme.C.textPrimary, action: onEnd)
        }
        .padding(.horizontal, Theme.S.s24)
        .frame(height: Theme.R.voicePanelHeight)
        .background(Theme.C.surfaceVoicePanel, in: Capsule())
        .subtleStroke(Capsule())
    }
}

/// Waveform: `voice.accent` bars fading toward the edges (100% → 30%). Driven only by the sound level, no decorative animation.
/// With "Reduce motion" — a static level bar (DESIGN.md §7).
struct Waveform: View {
    let levels: [Float]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                let level = CGFloat(levels.last ?? 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.C.voiceAccent.opacity(0.3))
                    Capsule().fill(Theme.C.voiceAccent).frame(width: geo.size.width * min(1, max(0, level)))
                }
                .frame(height: Theme.S.s4)
                .frame(maxHeight: .infinity)
            } else {
                let count = max(1, Int(geo.size.width / (Theme.R.waveBar + Theme.R.waveGap)))
                let values = Self.resample(levels, count: count)
                HStack(alignment: .center, spacing: Theme.R.waveGap) {
                    ForEach(0..<count, id: \.self) { i in
                        let edge = 1 - abs(Double(i) / Double(max(1, count - 1)) * 2 - 1)
                        Capsule()
                            .fill(Theme.C.voiceAccent.opacity(0.3 + 0.7 * edge))
                            .frame(width: Theme.R.waveBar,
                                   height: max(Theme.S.s4, geo.size.height * CGFloat(values[i])))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// The last `count` values; if there are fewer — silence on the left.
    static func resample(_ levels: [Float], count: Int) -> [Float] {
        let tail = Array(levels.suffix(count))
        return Array(repeating: 0, count: count - tail.count) + tail
    }
}

/// Input field (R-43, DESIGN.md §5).
struct InputBar: View {
    @Binding var text: String
    var enabled = true
    var disabledReason: String?
    var onSend: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.S.s12) {
            HStack(spacing: Theme.S.s16) {
                Image(systemName: "keyboard")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.C.textTertiary)
                    .accessibilityHidden(true)
                ColumnDivider().frame(height: Theme.S.s24)
                TextField("", text: $text, prompt: Text(enabled ? String(localized: "Write a message…") : (disabledReason ?? ""))
                    .foregroundStyle(Theme.C.textTertiary), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.F.rowTitle)
                    .foregroundStyle(Theme.C.textPrimary)
                    .lineLimit(1...4)
                    .focused($focused)
                    .disabled(!enabled)
                    .onKeyPress(.return, phases: .down) { press in
                        // Enter — send, ⇧Enter — new line (R-43).
                        if press.modifiers.contains(.shift) { return .ignored }
                        onSend()
                        return .handled
                    }
            }
            .padding(.horizontal, Theme.S.s20)
            .frame(minHeight: Theme.R.inputHeight)
            .background(Theme.C.surfaceInput, in: Capsule())
            .subtleStroke(Capsule())

            Button(action: onSend) {
                ZStack {
                    Circle().fill(Theme.C.surfaceSendButton)
                    Image(systemName: "paperplane")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.C.iconSend)
                }
                .frame(width: Theme.R.sendButton, height: Theme.R.sendButton)
            }
            .buttonStyle(LingoButtonStyle())
            .disabled(!enabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
    }
}
