import SwiftUI

/// XR-03: shown under a finished exam while the debrief is being written, and when it could not be (Retry sends one request per click).
/// LINGO-10 BR-31: a Goethe run with nothing finished to assess says so, with no Retry (there is nothing to send).
struct ExamDebriefCard: View {
    var running: Bool
    var nothingToAssess = false
    var onRetry: () -> Void
    var body: some View {
        HStack(spacing: Theme.S.s12) {
            if running {
                ProgressView().controlSize(.small).accessibilityHidden(true)
            } else if nothingToAssess {
                Image(systemName: "info.circle").font(.system(size: 18)).foregroundStyle(Theme.C.textSecondary).accessibilityHidden(true)
            } else {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 18)).foregroundStyle(Theme.C.statusDanger).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if nothingToAssess {
                    Text("Nothing finished to assess").font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                    Text("Finish a part with Done to get a debrief. Finish stops without assessing.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                } else {
                    Text(running ? "Writing the debrief…" : "Debrief not available").font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                    if !running {
                        Text("The models did not answer. Try again in a moment.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            if !running && !nothingToAssess { Button("Retry", action: onRetry).buttonStyle(LingoButtonStyle()) }
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }
}
