import LingoCore
import SwiftUI

/// The task stays above the transcript; long cards scroll within a bounded panel.
struct ExamPanel: View {
    let run: ExamRun
    let busy: Bool
    let followUp: Bool
    /// LINGO-10 BR-23: the panel names who is speaking.
    var speaker: ExamSpeaker? = nil
    var onDone: (ExamPhase) -> Void
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            HStack(spacing: Theme.S.s12) {
                Group {
                    if run.phase.isPreparation { Text("Preparation — microphone off") }
                    else { Text("Part \(run.phase.taskIndex + 1)") }
                }.font(Theme.F.hintPhrase)
                if let speaker {
                    Text(speaker == .examiner ? "Examiner" : "Partner").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = run.remaining(now: context.date)
                    Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(Theme.F.panelTitle).monospacedDigit()
                        .accessibilityLabel(Text("Time remaining") + Text(": \(seconds / 60):\(String(format: "%02d", seconds % 60))"))
                }
                Button("Done") { onDone(run.phase) }.buttonStyle(.borderedProminent)
                    .disabled(busy || followUp || run.finished)
                Button("Finish", action: onFinish).buttonStyle(LingoButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s8) {
                    task(run.task)
                    if run.phase == .goethePrep, run.tasks.count > 1, let presentation = ExamCatalog.task(run.tasks[1]) { task(presentation) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 160)
            if followUp {
                Text("Answer the examiner's follow-up question.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            } else if run.phase.isMonologue {
                Text("Speak until the timer ends, or say Done or press Done.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
        }
        .padding(Theme.S.s16).foregroundStyle(Theme.C.textPrimary)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .tint(Theme.accent(run.kind.lang))
    }

    private func task(_ value: ExamTask) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            Text(value.task).font(Theme.F.hintPhrase).textSelection(.enabled)
            ForEach(Array(value.points.enumerated()), id: \.offset) { index, point in
                Text("\(index + 1). \(point)").font(Theme.F.subtitle)
            }
        }
    }
}
