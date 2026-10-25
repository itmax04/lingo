import AppKit
import SwiftUI

/// Иконка приложения из токенов DESIGN.md: пузырь `accent.primary` с волной `voice.accent` на фоне `bg.window`.
/// `scripts/build-app.sh` вызывает `Lingo --export-iconset <папка>` и собирает .icns через iconutil.
struct AppIconView: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.22, style: .continuous).fill(Theme.C.bgWindow)
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Theme.C.accentPrimary)
                    .frame(width: s * 0.62, height: s * 0.46)
                    .offset(y: -s * 0.04)
                HStack(spacing: s * 0.035) {
                    ForEach([0.12, 0.22, 0.32, 0.22, 0.12], id: \.self) { h in
                        Capsule().fill(Theme.C.voiceAccent).frame(width: s * 0.045, height: s * h)
                    }
                }
                .offset(y: -s * 0.04)
            }
            .padding(s * 0.08)
        }
    }

    @MainActor
    static func exportIconset(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = base * scale
                let renderer = ImageRenderer(content: AppIconView().frame(width: CGFloat(px), height: CGFloat(px)))
                renderer.scale = 1
                guard let cg = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
                let rep = NSBitmapImageRep(cgImage: cg)
                guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try png.write(to: dir.appendingPathComponent(name))
            }
        }
    }
}
