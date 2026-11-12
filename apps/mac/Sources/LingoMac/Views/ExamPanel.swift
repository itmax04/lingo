import LingoCore
import SwiftUI

/// The task stays above the transcript; long cards scroll within a bounded panel.
struct ExamPanel: View {
    let run: ExamRun
    let busy: Bool
    let followUp: Bool
    /// LINGO-10 BR-23: the panel names who is speaking.
    var speaker: ExamSpeaker? = nil
    /// LINGO-10 BR-22: the learner's notes of a Training run (Teil 2 and Teil 3). Memory only.
    var notes: Binding<String>? = nil
    var onDone: (ExamPhase) -> Void
    var onFinish: () -> Void
    /// LINGO-10 BR-17: Replay of the partner's talk in Training.
    var onReplay: () -> Void = {}

    private var training: Bool { run.format == .training }
    private var talkPart: Bool { run.phase == .goethePartner }
    /// Done is blocked while a model reply runs, but never during the partner's talk or the line before it: Done stops the talk (BR-13)
    /// and a Done during the Examiner line is applied when the line has ended (G-3).
    var doneDisabled: Bool { run.finished || (!talkPart && (busy || followUp)) }

    /// LINGO-10 R-5: "Part N" for the parts that have a number; the introduction and the two Teil 3 sub-parts say what they are.
    enum PartLabel: Equatable { case number(Int), introduction, partnerTalk, feedback }
    var partLabel: PartLabel {
        guard run.format != nil else { return .number(run.phase.taskIndex + 1) }
        switch run.phase {
        case .goetheIntro: return .introduction
        case .goethePartner: return .partnerTalk
        case .goetheFeedback: return .feedback
        default: return .number(run.phase.taskIndex + 1)
        }
    }
    private var partTitle: Text {
        switch partLabel {
        case .number(let n): Text("Part \(n)")
        case .introduction: Text("Introduction")
        case .partnerTalk: Text("Part 3 · Partner's talk")
        case .feedback: Text("Part 3 · Feedback and question")
        }
    }

    /// The body scrolls inside a bounded panel. The visible talk (BR-17) needs a guaranteed minimum: the message list below is greedy,
    /// and without it the scroll view was squeezed to the task lines and the talk text never appeared.
    var bodyHeight: (min: CGFloat, max: CGFloat) { training && talkPart ? (200, 320) : (160, 160) }

    var notesTitle: LocalizedStringKey? {
        guard notes != nil else { return nil }
        if run.format == .mock { return "My notes" }  // BR-22: one field for the whole Mock
        guard training else { return nil }
        switch run.teil {
        case 2?: return "My presentation plan"
        case 3?: return "My notes"
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            HStack(spacing: Theme.S.s12) {
                Group {
                    if run.phase.isPreparation { Text("Preparation — microphone off") }
                    else { partTitle }
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
                if training && talkPart {
                    Button("Replay", action: onReplay).buttonStyle(LingoButtonStyle())
                        .accessibilityLabel("Replay the talk")
                }
                Button("Done") { onDone(run.phase) }.buttonStyle(.borderedProminent)
                    .disabled(doneDisabled)
                Button("Finish", action: onFinish).buttonStyle(LingoButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s8) {
                    task(run.task)
                    if run.phase == .goethePrep, run.tasks.count > 1, let presentation = ExamCatalog.task(run.tasks[1]) { task(presentation) }
                    // BR-17: in Training the partner's talk is visible. In Mock it stays hidden (BR-13).
                    if training, talkPart, let talk = run.task.talk {
                        Text(verbatim: talk).font(Theme.F.subtitle).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: bodyHeight.min, maxHeight: bodyHeight.max)
            if let notesTitle, let notes {
                VStack(alignment: .leading, spacing: Theme.S.s4) {
                    Text(notesTitle).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
                    TextEditor(text: Binding(get: { notes.wrappedValue }, set: { notes.wrappedValue = String($0.prefix(AppModel.notesLimit)) }))
                        .font(Theme.F.subtitle).scrollContentBackground(.hidden).padding(Theme.S.s4)
                        .frame(height: 72)
                        .background(Theme.C.bgWindow, in: RoundedRectangle(cornerRadius: Theme.R.button))
                        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
                        .accessibilityLabel(notesTitle)
                }
            }
            if followUp {
                Text("Answer the examiner's follow-up question.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            } else if run.phase.isMonologue {
                Text("Speak until the timer ends, or say Done or press Done.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            if training {
                Text("Done completes the part and gives the debrief. Finish stops without assessing what is unfinished.")
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
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
