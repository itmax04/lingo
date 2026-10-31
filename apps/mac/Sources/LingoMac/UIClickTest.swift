import AppKit
import LingoCore
import SwiftUI

/// `Lingo --ui-click-test`: the voice panel in an off-screen window receives mouse events at the center of each button;
/// prints which actions fired (analysis of "the microphone button does not respond", H-2).
@MainActor
enum UIClickTest {
    final class Hits { var mic = 0, pause = 0, end = 0 }

    static func run() -> Int32 {
        NSApplication.shared.setActivationPolicy(.accessory)
        let hits = Hits()
        let size = NSSize(width: 900, height: Theme.R.voicePanelHeight)
        let view = VoicePanel(state: .idle, levels: [], onMic: { hits.mic += 1 }, onPause: { hits.pause += 1 }, onEnd: { hits.end += 1 })
            .frame(width: size.width, height: size.height)
            .environment(\.locale, Locale(identifier: "en"))
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: NSRect(x: 100, y: 100, width: size.width, height: size.height), styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = hosting
        w.makeKeyAndOrderFront(nil)
        for _ in 0..<6 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)); hosting.layoutSubtreeIfNeeded() }
        func click(_ p: NSPoint) {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let e = NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: w.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                    w.sendEvent(e)
                }
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
        }
        // The compact panel has 16 pt side padding and a 12 pt top inset. Use the English
        // fixture captions so both secondary controls stay 36 pt wide.
        click(NSPoint(x: 16 + 22, y: size.height - 39))
        click(NSPoint(x: size.width - 16 - 18, y: size.height - 30))
        click(NSPoint(x: size.width - 16 - 36 - 12 - 18, y: size.height - 30))
        print("ui-click-test: mic=\(hits.mic) pause=\(hits.pause) end=\(hits.end)")
        return hits.mic == 1 && hits.pause == 1 && hits.end == 1 ? 0 : 1
    }
}
