import AppKit
import Foundation
import LingoCore
import Metal

/// `--quit-check`: loads the recognition model, runs one recognition on the GPU, starts a second long one and quits through
/// `NSApplication.terminate` while it runs — the ⌘Q path with a recognition in flight. Before the fix, ggml aborted in `exit` while
/// tearing down its Metal devices (exit by SIGABRT); now the process must exit with 0. Exit 2: the model is not installed (nothing is
/// downloaded); exit 3: no Metal device, so the GPU path would not be exercised. No journal, no network, no microphone.
@MainActor
enum QuitCheck {
    /// Kept alive until the quit, like `AppServices.whisper` in the app.
    nonisolated(unsafe) static var engine: WhisperEngine?

    static func run() {
        guard MTLCreateSystemDefaultDevice() != nil else { print("quit-check: no Metal device"); exit(3) }
        let store = ModelStore.macDefault
        guard store.isInstalled(.largeV3TurboQ5) else { print("quit-check: model not installed"); exit(2) }
        let path = store.path(.largeV3TurboQ5).path
        Task {
            do {
                try await Task.detached {
                    let w = try WhisperEngine(modelPath: path)
                    // One second of a 440 Hz tone: loud enough to pass the silence gate, so whisper allocates its GPU buffers.
                    _ = try w.transcribeSync(tone(seconds: 1), candidates: [.en], forced: .en)
                    QuitCheck.engine = w
                }.value
            } catch {
                print("quit-check: \(error)")
                exit(2)
            }
            // A long recognition in flight when the app quits: `closeAll()` must cancel it and wait before freeing the context.
            Task.detached { _ = try? QuitCheck.engine?.transcribeSync(tone(seconds: 20), candidates: [.en], forced: .en) }
            try? await Task.sleep(for: .milliseconds(300))
            print("quit-check: GPU recognition done; terminating during a second one")
            NSApp.terminate(nil)
        }
    }

    nonisolated static func tone(seconds: Int) -> [Float] {
        (0..<(16_000 * seconds)).map { Float(0.2 * sin(2 * Double.pi * 440 * Double($0) / 16_000)) }
    }
}
