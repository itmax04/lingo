import AppKit
import LingoCore
import SwiftUI

/// First-launch wizard (R-45): 1) microphone and speech-recognition permissions; 2) a Groq key (can be skipped — voice stays inactive);
/// 3) sync folder (can be skipped).
struct OnboardingView: View {
    let services: AppServices
    let keys: KeysController
    let onDone: () -> Void
    @State private var step = 0
    @State private var mic = Permissions.microphone
    @State private var speech = Permissions.speech

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Welcome to Lingo").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
            Text("Step \(step + 1) of 3").font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            switch step {
            case 0:
                SettingsCard(title: "Microphone and speech recognition",
                             subtitle: "Lingo listens to your speech and recognizes it on this Mac. Audio is not saved and never goes to the network — only text is sent to the model.") {
                    status(String(localized: "Microphone"), mic)
                    status(String(localized: "Speech recognition"), speech)
                    Button("Allow") {
                        Task {
                            _ = await Permissions.requestMicrophone()
                            _ = await Permissions.requestSpeech()
                            mic = Permissions.microphone
                            speech = Permissions.speech
                            if mic == .granted { services.prepareVoice() }
                        }
                    }
                    if mic == .denied {
                        Text("Access denied. Turn on Lingo: System Settings → Privacy & Security → Microphone.")
                            .font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                    }
                }
            case 1:
                ProviderKeysCard(keys: keys, provider: .groq)
                Text("Without a key, voice and model replies are inactive; you can add a key later in Settings.")
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            default:
                SettingsCard(title: "Sync folder",
                             subtitle: "To share the history with an iPhone (LINGO-02), choose the “Lingo” folder in iCloud Drive. The history is always kept on this Mac as well.") {
                    Text(services.model.syncFolderPath ?? String(localized: "Not selected")).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                    Button("Choose a folder…") { services.chooseSyncFolder() }
                }
            }
            Spacer(minLength: 0)
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                if step > 0 { Button("Skip") { next() } }
                Button(step == 2 ? "Done" : "Next") { next() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 680, height: 520)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
    }

    func next() {
        if step < 2 { step += 1 } else {
            services.updateSettings { $0.onboardingDone = true }
            onDone()
        }
    }

    func status(_ title: String, _ s: Permissions.State) -> some View {
        HStack(spacing: Theme.S.s8) {
            Circle().fill(s == .granted ? Theme.C.statusSuccess : Theme.C.statusDanger).frame(width: Theme.S.s8, height: Theme.S.s8)
            Text(verbatim: "\(title): \(s == .granted ? String(localized: "allowed") : (s == .denied ? String(localized: "denied") : String(localized: "not requested")))")
                .font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
        }
    }
}
