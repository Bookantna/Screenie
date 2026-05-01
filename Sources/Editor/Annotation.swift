import SwiftUI

enum AnnotationTool: String, CaseIterable {
    case arrow, rectangle, highlight, text, blur, callout

    var icon: String {
        switch self {
        case .arrow:     "arrow.up.right"
        case .rectangle: "rectangle"
        case .highlight: "highlighter"
        case .text:      "textformat"
        case .blur:      "eye.slash"
        case .callout:   "number.circle.fill"
        }
    }
    var label: String { rawValue.capitalized }
}

enum Annotation: Identifiable {
    case arrow(Arrow)
    case rect(Rect)
    case highlight(Highlight)
    case text(TextLabel)
    case blur(Blur)
    case callout(Callout)

    var id: UUID {
        switch self {
        case .arrow(let a):     a.id
        case .rect(let r):      r.id
        case .highlight(let h): h.id
        case .text(let t):      t.id
        case .blur(let b):      b.id
        case .callout(let c):   c.id
        }
    }

    struct Arrow: Identifiable {
        var id = UUID()
        var start, end: CGPoint
        var color: Color
        var lineWidth: CGFloat
    }

    struct Rect: Identifiable {
        var id = UUID()
        var rect: CGRect
        var color: Color
        var lineWidth: CGFloat
    }

    struct Highlight: Identifiable {
        var id = UUID()
        var rect: CGRect
    }

    struct TextLabel: Identifiable {
        var id = UUID()
        var origin: CGPoint
        var content: String
        var color: Color
        var fontSize: CGFloat
    }

    struct Blur: Identifiable {
        var id = UUID()
        var rect: CGRect
    }

    struct Callout: Identifiable {
        var id = UUID()
        var center: CGPoint
        var number: Int
        var color: Color
    }

    func draw(in ctx: inout GraphicsContext) {
        switch self {
        case .arrow(let a):     drawArrow(a, in: &ctx)
        case .rect(let r):      drawRect(r, in: &ctx)
        case .highlight(let h): drawHighlight(h, in: &ctx)
        case .text(let t):      drawText(t, in: &ctx)
        case .blur(let b):      drawBlurPlaceholder(b, in: &ctx)
        case .callout(let c):   drawCallout(c, in: &ctx)
        }
    }

    // Canvas draws a frosted placeholder; real pixelation is applied in AnnotationCanvas and ExportManager
    private func drawBlurPlaceholder(_ b: Blur, in ctx: inout GraphicsContext) {
        ctx.fill(Path(b.rect), with: .color(.gray.opacity(0.01))) // invisible; real blur rendered separately
    }

    private func drawArrow(_ a: Arrow, in ctx: inout GraphicsContext) {
        var path = Path()
        path.move(to: a.start)
        path.addLine(to: a.end)
        ctx.stroke(path, with: .color(a.color), style: StrokeStyle(lineWidth: a.lineWidth, lineCap: .round))

        let angle = atan2(a.end.y - a.start.y, a.end.x - a.start.x)
        let headLen: CGFloat = max(10, a.lineWidth * 4)
        let spread: CGFloat = .pi / 6
        var head = Path()
        head.move(to: a.end)
        head.addLine(to: CGPoint(
            x: a.end.x - headLen * cos(angle - spread),
            y: a.end.y - headLen * sin(angle - spread)
        ))
        head.move(to: a.end)
        head.addLine(to: CGPoint(
            x: a.end.x - headLen * cos(angle + spread),
            y: a.end.y - headLen * sin(angle + spread)
        ))
        ctx.stroke(head, with: .color(a.color), style: StrokeStyle(lineWidth: a.lineWidth, lineCap: .round))
    }

    private func drawRect(_ r: Rect, in ctx: inout GraphicsContext) {
        ctx.stroke(Path(r.rect), with: .color(r.color), style: StrokeStyle(lineWidth: r.lineWidth))
    }

    private func drawHighlight(_ h: Highlight, in ctx: inout GraphicsContext) {
        ctx.fill(Path(h.rect), with: .color(.yellow.opacity(0.4)))
    }

    private func drawText(_ t: TextLabel, in ctx: inout GraphicsContext) {
        let label = Text(t.content)
            .font(.system(size: t.fontSize, weight: .semibold))
            .foregroundStyle(t.color)
        ctx.draw(label, at: t.origin, anchor: .topLeading)
    }

    private func drawCallout(_ c: Callout, in ctx: inout GraphicsContext) {
        let radius: CGFloat = 14
        let rect = CGRect(x: c.center.x - radius, y: c.center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(c.color))
        let label = Text("\(c.number)")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
        ctx.draw(label, at: c.center, anchor: .center)
    }
}
