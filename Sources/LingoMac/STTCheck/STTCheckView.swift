import AppKit
import LingoCore
import SwiftUI

/// The "Speech recognition check" window (H-2, H-4). A service window: not in the mockup; tokens come from DESIGN.md.
struct STTCheckView: View {
    @Bindable var c: STTCheckController

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            header
            if let step = c.current {
                PhraseCard(step: step, number: c.index + 1, total: c.steps.count)
                VoicePanel(state: c.recording ? .recording : (c.busy ? .thinking : .idle), levels: c.levels,
                           onMic: { c.toggleRecording() }, onPause: { c.previous() }, onEnd: { c.next() })
                Text(c.status).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary)
                if let r = c.currentResult { ResultCard(c: c, r: r) }
            }
            SummaryCard(lines: c.summaryLines(), file: c.fileURL.path)
            Spacer(minLength: 0)
        }
        .padding(Theme.S.s24)
        .frame(minWidth: 860, minHeight: 760, alignment: .topLeading)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
        .task { await c.prepare() }
        .onKeyPress(.space) { c.toggleRecording(); return .handled }
    }

    @ViewBuilder private var header: some View {
        Text(c.part == "part1" ? "Speech recognition check — part 1 (H-2)" : "Speech recognition check — part 2 (H-4)")
            .font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
        Text("Read the phrase aloud at your normal pace. Audio is not saved: only texts and numbers are written to the file.")
            .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
        if let p = c.permissionProblem {
            Text(p).font(Theme.F.rowTitle).foregroundStyle(Theme.C.statusDanger)
        }
    }
}

struct PhraseCard: View {
    let step: STTCheckController.Step
    let number: Int
    let total: Int

    var label: String {
        let study = step.phrase.study == "de" ? "Deutsch" : "English"
        switch step.phrase.lang {
        case "en": return "English"
        case "de": return "Deutsch"
        case "ru": return String(localized: "Russian (session \(study))")
        default: return String(localized: "Mixed (\(step.phrase.study) + ru)")
        }
    }

    var body: some View {
        SettingsCard(title: "Phrase \(number) of \(total) · \(label)") {
            Text(step.phrase.text).font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if step.forced {
                Text("“I'm speaking Russian” button mode: the same phrase, recognized with the button.")
                    .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.voiceAccent)
            }
        }
    }
}

struct ResultCard: View {
    let c: STTCheckController
    let r: STTCheckController.Result

    var body: some View {
        SettingsCard(title: "Recognized (\(String(format: "%.1f", r.audioSec)) s of audio)") {
            ForEach(r.results, id: \.engine) { e in EngineLine(e: e) }
            HStack(spacing: Theme.S.s12) {
                Button("Understandable ✓") { c.mark(true) }.keyboardShortcut(.return, modifiers: [])
                Button("Not understandable ✗") { c.mark(false) }
                Button("Record again") { c.startRecording() }
                if let a = r.accepted {
                    Text(a ? "marked: understandable" : "marked: not understandable").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
        }
    }
}

struct EngineLine: View {
    let e: STTCheckController.EngineResult

    var meta: String {
        let name = e.engine.hasPrefix("whisper") ? "whisper" : "Apple"
        return "\(name) · " + String(localized: "language \(e.lang.uppercased())") + " · WER \(Int((e.wer * 100).rounded()))% · " + String(localized: "\(Int(e.ms)) ms")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text(meta).font(Theme.F.meta).foregroundStyle(e.wer <= 0.25 ? Theme.C.statusSuccess : Theme.C.statusDanger)
            Text(e.text).font(Theme.F.bubble).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
        }
    }
}

struct SummaryCard: View {
    let lines: [String]
    let file: String

    var body: some View {
        SettingsCard(title: "Totals (whisper / Apple)") {
            ForEach(lines, id: \.self) { Text($0).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary) }
            Text("File: \(file)").font(Theme.F.meta).foregroundStyle(Theme.C.textTertiary).textSelection(.enabled)
        }
    }
}

@MainActor
enum STTCheckWindow {
    static var window: NSWindow?
    static var controller: STTCheckController?

    static func show(part: String) {
        let c = STTCheckController(part: part)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 880), styleMask: [.titled, .closable, .resizable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = String(localized: "Speech recognition check")
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = NSHostingView(rootView: STTCheckView(c: c))
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = w
        controller = c
    }
}
