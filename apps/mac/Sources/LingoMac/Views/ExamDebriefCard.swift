import SwiftUI

/// XR-03: shown under a finished exam while the debrief is being written, and when it could not be (Retry sends one request per click).
struct ExamDebriefCard: View {
    var running: Bool
    var onRetry: () -> Void
    var body: some View {
        HStack(spacing: Theme.S.s12) {
            if running {
                ProgressView().controlSize(.small).accessibilityHidden(true)
            } else {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 18)).foregroundStyle(Theme.C.statusDanger).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(running ? "Writing the debrief…" : "Debrief not available").font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                if !running {
                    Text("The models did not answer. Try again in a moment.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if !running { Button("Retry", action: onRetry).buttonStyle(LingoButtonStyle()) }
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }
}
