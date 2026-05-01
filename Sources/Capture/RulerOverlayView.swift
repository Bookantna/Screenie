import SwiftUI
import AppKit

// Shown inside a full-screen overlay window; user clicks two points to measure distance.
struct RulerOverlayView: View {
    let onMeasure: (CGFloat) -> Void   // distance in points (= pixels on 1x, /2 on Retina)
    let onCancel: () -> Void

    @State private var first: CGPoint?
    @State private var second: CGPoint?
    @State private var hover: CGPoint?

    private var distance: CGFloat? {
        guard let a = first, let b = second ?? hover else { return nil }
        return hypot(b.x - a.x, b.y - a.y)
    }

    private var lineEnd: CGPoint? { second ?? hover }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.15)

                if let a = first, let b = lineEnd {
                    // Measurement line
                    Path { p in
                        p.move(to: a)
                        p.addLine(to: b)
                    }
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))

                    // End-cap ticks
                    ForEach([a, b], id: \.x) { pt in
                        let angle = atan2(b.y - a.y, b.x - a.x)
                        Path { p in
                            let tick: CGFloat = 6
                            p.move(to: CGPoint(x: pt.x - tick * sin(angle),
                                               y: pt.y + tick * cos(angle)))
                            p.addLine(to: CGPoint(x: pt.x + tick * sin(angle),
                                                  y: pt.y - tick * cos(angle)))
                        }
                        .stroke(Color.yellow, lineWidth: 1.5)
                    }

                    // Distance label
                    if let d = distance {
                        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                        Text("\(Int(d)) px")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                            .position(x: mid.x, y: mid.y - 16)
                    }
                }

                // First point dot
                if let a = first {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                        .position(a)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let loc) = phase { hover = loc }
            }
            .onTapGesture { location in
                if first == nil {
                    first = location
                } else {
                    second = location
                    if let d = distance { onMeasure(d) }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { NSCursor.crosshair.push() }
        .onDisappear { NSCursor.pop() }
    }
}

@MainActor
final class RulerOverlayWindow: NSWindow {
    private var continuation: CheckedContinuation<CGFloat?, Never>?
    private var keyMonitor: Any?

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false

        contentView = NSHostingView(rootView: RulerOverlayView(
            onMeasure: { [weak self] dist in self?.finish(dist) },
            onCancel:  { [weak self] in self?.finish(nil) }
        ))
    }

    func measure() async -> CGFloat? {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil); return nil }
            return event
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return await withCheckedContinuation { self.continuation = $0 }
    }

    private func finish(_ value: CGFloat?) {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        orderOut(nil)
        continuation?.resume(returning: value)
        continuation = nil
    }
}
