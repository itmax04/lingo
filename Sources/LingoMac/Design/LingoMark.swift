import SwiftUI

/// Two overlapping speech-wave arcs, built as a vector rather than an embedded mockup.
struct LingoGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.45, y: r.minY + h * 0.76))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.38, y: r.minY + h * 0.12),
                   control1: CGPoint(x: r.minX + w * 0.06, y: r.minY + h * 0.9),
                   control2: CGPoint(x: r.minX + w * 0.04, y: r.minY + h * 0.06))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.54, y: r.minY + h * 0.82),
                   control1: CGPoint(x: r.minX + w * 0.7, y: r.minY + h * 0.13),
                   control2: CGPoint(x: r.minX + w * 0.45, y: r.minY + h * 0.62))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.7, y: r.minY + h * 0.35),
                   control1: CGPoint(x: r.minX + w * 0.89, y: r.minY + h * 1.05),
                   control2: CGPoint(x: r.minX + w * 1.02, y: r.minY + h * 0.46))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.42, y: r.minY + h * 0.42),
                   control1: CGPoint(x: r.minX + w * 0.52, y: r.minY + h * 0.26),
                   control2: CGPoint(x: r.minX + w * 0.4, y: r.minY + h * 0.3))
        return p
    }
}

struct LingoMark: View {
    var color = Theme.C.accentPrimary
    var speaking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    var body: some View {
        LingoGlyph().stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .padding(4)
            .scaleEffect(speaking && !reduceMotion && expanded ? 1.06 : 1)
            .onAppear { breathe() }
            .onChange(of: speaking) { _, _ in breathe() }
            .onChange(of: reduceMotion) { _, _ in breathe() }
            .transaction { if reduceMotion || !speaking { $0.animation = nil; $0.disablesAnimations = true } }
            .accessibilityHidden(true)
    }
    private func breathe() {
        expanded = false
        guard speaking && !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { expanded = true }
    }
}
