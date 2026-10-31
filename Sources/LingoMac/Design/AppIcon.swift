import AppKit
import SwiftUI

/// Production ImageGen icon (permitted bitmap exception), with a vector mark fallback.
/// `scripts/build-app.sh` calls `Lingo --export-iconset <dir>` and builds the .icns with iconutil.
struct AppIconView: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.22, style: .continuous).fill(Theme.C.bgWindow)
                LingoGlyph().stroke(Color(red: 242/255, green: 184/255, blue: 91/255), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round, lineJoin: .round))
                    .frame(width: s * 0.62, height: s * 0.62)
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
                let source = CommandLine.arguments.firstIndex(of: "--icon-source").flatMap { index in
                    CommandLine.arguments.indices.contains(index + 1) ? NSImage(contentsOfFile: CommandLine.arguments[index + 1]) : nil
                }
                let rep: NSBitmapImageRep
                if let source, let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                                          samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                   let context = NSGraphicsContext(bitmapImageRep: bitmap) {
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = context
                    context.imageInterpolation = .high
                    source.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
                    NSGraphicsContext.restoreGraphicsState()
                    rep = bitmap
                } else {
                    guard let cg = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
                    rep = NSBitmapImageRep(cgImage: cg)
                }
                guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try png.write(to: dir.appendingPathComponent(name))
            }
        }
    }
}
