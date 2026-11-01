import AppKit
import Foundation
import LingoCore

/// `--quit-check`: loads the recognition model, runs one recognition on the GPU and quits through `NSApplication.terminate`, the same
/// path as ⌘Q. Before the fix, ggml aborted in `exit` while tearing down its Metal devices (exit by SIGABRT); now the process must
/// exit with 0. No journal, no network, no microphone.
@MainActor
enum QuitCheck {
    /// Kept alive until the quit, like `AppServices.whisper` in the app.
    nonisolated(unsafe) static var engine: WhisperEngine?

    static func run() {
        Task {
            do {
                let path = try await ModelStore.macDefault.ensure(.largeV3TurboQ5)
                let text = try await Task.detached { () -> String in
                    let w = try WhisperEngine(modelPath: path.path)
                    // One second of a 440 Hz tone: loud enough to pass the silence gate, so whisper allocates its GPU buffers.
                    let tone = (0..<16_000).map { Float(0.2 * sin(2 * Double.pi * 440 * Double($0) / 16_000)) }
                    _ = try w.transcribeSync(tone, candidates: [.en], forced: .en)
                    QuitCheck.engine = w
                    return "recognized"
                }.value
                print("quit-check: \(text); terminating")
            } catch {
                print("quit-check: \(error)")
                exit(2)
            }
            NSApp.terminate(nil)
        }
    }
}
