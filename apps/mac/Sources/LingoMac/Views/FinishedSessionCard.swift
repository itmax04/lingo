import SwiftUI

/// Shown instead of live input when the selected session is finished (R-22): voice and typing stay off until the learner
/// explicitly continues the session (R-01) or starts a new one.
struct FinishedSessionCard: View {
    var onContinue: () -> Void
    var onNew: () -> Void
    var body: some View {
        HStack(spacing: Theme.S.s12) {
            Image(systemName: "checkmark.circle").font(.system(size: 18)).foregroundStyle(Theme.C.statusSuccess).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Session finished").font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                Text("The microphone is off. Continue this session or start a new one.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            Spacer(minLength: 0)
            Button("Continue session", action: onContinue).buttonStyle(LingoButtonStyle())
            Button("New session", action: onNew).buttonStyle(LingoButtonStyle())
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }
}
