import AppKit
import LingoCore
import SwiftUI

/// Окно «Проверка распознавания» (H-2, H-4). Служебное: на макете его нет, токены — из DESIGN.md.
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
        Text(c.part == "part1" ? "Проверка распознавания — часть 1 (H-2)" : "Проверка распознавания — часть 2 (H-4)")
            .font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
        Text("Прочитайте фразу вслух обычным темпом. Звук не сохраняется: в файл пишутся только тексты и числа.")
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
        case "ru": return "Русский (сессия \(study))"
        default: return "Смешанная (\(step.phrase.study) + ru)"
        }
    }

    var body: some View {
        SettingsCard(title: "Фраза \(number) из \(total) · \(label)") {
            Text(step.phrase.text).font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if step.forced {
                Text("Режим кнопки «Говорю по-русски»: фраза та же, распознавание — с кнопкой.")
                    .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.voiceAccent)
            }
        }
    }
}

struct ResultCard: View {
    let c: STTCheckController
    let r: STTCheckController.Result

    var body: some View {
        SettingsCard(title: "Распознано (\(String(format: "%.1f", r.audioSec)) с звука)") {
            ForEach(r.results, id: \.engine) { e in EngineLine(e: e) }
            HStack(spacing: Theme.S.s12) {
                Button("Понятно ✓") { c.mark(true) }.keyboardShortcut(.return, modifiers: [])
                Button("Непонятно ✗") { c.mark(false) }
                Button("Записать заново") { c.startRecording() }
                if let a = r.accepted {
                    Text(a ? "отмечено: понятно" : "отмечено: непонятно").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
        }
    }
}

struct EngineLine: View {
    let e: STTCheckController.EngineResult

    var meta: String {
        let name = e.engine.hasPrefix("whisper") ? "whisper" : "Apple"
        return "\(name) · язык \(e.lang.uppercased()) · WER \(Int((e.wer * 100).rounded()))% · \(Int(e.ms)) мс"
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
        SettingsCard(title: "Итоги (whisper / Apple)") {
            ForEach(lines, id: \.self) { Text($0).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary) }
            Text("Файл: \(file)").font(Theme.F.meta).foregroundStyle(Theme.C.textTertiary).textSelection(.enabled)
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
        w.title = "Проверка распознавания"
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
