import LingoCore
import SwiftUI

/// Voice panel (R-42, DESIGN.md §5): microphone and state, waveform from the sound level, "Pause", "Finish".
struct VoicePanel: View {
    let state: VoiceState
    let levels: [Float]
    var lang: Lang = .de
    var unavailable: String?
    var onMic: () -> Void = {}
    var onPause: () -> Void = {}
    var onEnd: () -> Void = {}
    var extraControls: AnyView = AnyView(EmptyView())


    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onMic) {
                    Image(systemName: state == .idle ? "mic" : "waveform")
                        .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.accent(lang))
                        .frame(width: Theme.R.micCircle, height: Theme.R.micCircle)
                        .background(Theme.accentSurface(lang), in: Circle())
                }.buttonStyle(LingoButtonStyle()).accessibilityLabel("Speak")
                VStack(alignment: .leading, spacing: 4) {
                    Text(unavailable ?? state.title).font(Theme.F.voiceState)
                        .foregroundStyle(unavailable == nil ? Theme.accent(lang) : Theme.C.statusDanger).lineLimit(2)
                    if state == .thinking { ProgressView().controlSize(.mini).accessibilityLabel("Thinking…") }
                }.frame(minWidth: 76, alignment: .leading)
                Waveform(levels: unavailable == nil && [.recording, .listening, .speaking].contains(state) ? levels : [], color: Theme.accent(lang))
                    .frame(maxWidth: .infinity).frame(height: 36).accessibilityHidden(true)
                RoundCaptionButton(symbol: state == .paused ? "play.fill" : "pause.fill",
                                   caption: state == .paused ? "Resume" : "Pause",
                                   fill: Theme.C.surfaceControl, iconColor: Theme.C.textPrimary, action: onPause)
                RoundCaptionButton(symbol: "xmark", caption: "Finish",
                                   fill: Theme.C.surfaceControl, iconColor: Theme.C.statusDanger, action: onEnd)
            }
            HStack { extraControls; Spacer(minLength: 0) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(height: Theme.R.voicePanelHeight)
        .background(Theme.C.surfaceVoicePanel, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}

/// Waveform: `voice.accent` bars fading toward the edges (100% → 30%). Driven only by the sound level, no decorative animation.
/// With "Reduce motion" — a static level bar (DESIGN.md §7).
/// A single line driven by captured sound levels. Reduce Motion uses a level meter.
struct Waveform: View {
    let levels: [Float]
    var color = Theme.C.voiceAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            if reduceMotion {
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.16))
                    Capsule().fill(color).frame(width: geometry.size.width * CGFloat(min(1, max(0, levels.last ?? 0))))
                }.frame(height: 4).frame(maxHeight: .infinity)
            } else {
                Path { path in
                    let count = max(2, Int(geometry.size.width / 4))
                    let values = Self.resample(levels, count: count)
                    for index in 0..<count {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(count - 1)
                        let value = CGFloat(min(1, max(0, values[index])))
                        let y = geometry.size.height / 2 + sin(CGFloat(index) * 0.55) * value * geometry.size.height * 0.4
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
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
