import SwiftUI
import AppKit

struct CaptureOverlayView: View {
    let onSelect: (CGRect?) -> Void
    var screenImage: CGImage? = nil
    var screenScale: CGFloat = 1.0

    @State private var start: CGPoint?
    @State private var current: CGPoint?
    @State private var hoverPoint: CGPoint?

    private var selection: CGRect? {
        guard let s = start, let c = current else { return nil }
        return CGRect(
            x: min(s.x, c.x), y: min(s.y, c.y),
            width: abs(c.x - s.x), height: abs(c.y - s.y)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.25)

                if let sel = selection, sel.width > 2, sel.height > 2 {
                    Rectangle()
                        .blendMode(.destinationOut)
                        .frame(width: sel.width, height: sel.height)
                        .position(x: sel.midX, y: sel.midY)

                    Rectangle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        .frame(width: sel.width, height: sel.height)
                        .position(x: sel.midX, y: sel.midY)

                    Text("\(Int(sel.width)) × \(Int(sel.height))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                        .position(
                            x: min(max(sel.midX, 48), geo.size.width - 48),
                            y: sel.minY > 28 ? sel.minY - 16 : sel.maxY + 16
                        )
                }

                // Magnifier loupe — only visible before drag starts
                if start == nil, let pt = hoverPoint, let img = screenImage {
                    LoupeView(image: img, center: pt, scale: screenScale)
                        .position(loupePosition(pt, in: geo.size))
                        .allowsHitTesting(false)
                }
            }
            .compositingGroup()
            .onContinuousHover { phase in
                if case .active(let loc) = phase { hoverPoint = loc } else { hoverPoint = nil }
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { v in
                        if start == nil { start = v.startLocation }
                        current = v.location
                    }
                    .onEnded { _ in
                        defer { start = nil; current = nil }
                        guard let sel = selection, sel.width > 5, sel.height > 5 else {
                            onSelect(nil)
                            return
                        }
                        onSelect(sel)
                    }
            )
        }
        .ignoresSafeArea()
    }

    private func loupePosition(_ pt: CGPoint, in size: CGSize) -> CGPoint {
        let half: CGFloat = 80  // LoupeView is 160×160
        let margin: CGFloat = 24
        var x = pt.x + half + margin
        var y = pt.y - half - margin
        if x + half > size.width  { x = pt.x - half - margin }
        if y - half < 0           { y = pt.y + half + margin }
        return CGPoint(x: x, y: y)
    }
}

// MARK: – Loupe

private struct LoupeView: View {
    let image: CGImage
    let center: CGPoint
    let scale: CGFloat

    private let viewSize: CGFloat = 160
    private let srcRadius: CGFloat = 20  // capture a 40×40 pt region around cursor

    var body: some View {
        Canvas { ctx, canvasSize in
            let halfPx = srcRadius * scale
            let px = center.x * scale
            // CG images have y-origin at bottom; SwiftUI local space has it at top
            let py = CGFloat(image.height) - center.y * scale

            let maxX = max(0, CGFloat(image.width)  - halfPx * 2)
            let maxY = max(0, CGFloat(image.height) - halfPx * 2)
            let srcX = min(max(px - halfPx, 0), maxX)
            let srcY = min(max(py - halfPx, 0), maxY)
            let srcRect = CGRect(x: srcX, y: srcY, width: halfPx * 2, height: halfPx * 2)

            if let cropped = image.cropping(to: srcRect) {
                let nsImg = NSImage(cgImage: cropped, size: canvasSize)
                let resolved = ctx.resolve(Image(nsImage: nsImg))
                ctx.draw(resolved, in: CGRect(origin: .zero, size: canvasSize))
            }

            // Crosshair
            let mid = canvasSize.width / 2
            var h = Path()
            h.move(to: CGPoint(x: 0, y: mid))
            h.addLine(to: CGPoint(x: canvasSize.width, y: mid))
            var v = Path()
            v.move(to: CGPoint(x: mid, y: 0))
            v.addLine(to: CGPoint(x: mid, y: canvasSize.height))
            ctx.stroke(h, with: .color(.white.opacity(0.75)), lineWidth: 1)
            ctx.stroke(v, with: .color(.white.opacity(0.75)), lineWidth: 1)
        }
        .frame(width: viewSize, height: viewSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }
}
