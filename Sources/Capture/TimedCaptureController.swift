import AppKit
import SwiftUI

@MainActor
final class TimedCaptureController {
    func countdownThenCapture(seconds: Int, action: @escaping @MainActor () async -> Void) {
        let window = CountdownWindow(seconds: seconds) {
            Task { await action() }
        }
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class CountdownWindow: NSWindow {
    private var remaining: Int
    private var timer: Timer?
    private let onFire: () -> Void
    private let hostingView: NSHostingView<CountdownView>
    @MainActor private var countState: CountdownView.State

    init(seconds: Int, onFire: @escaping () -> Void) {
        self.remaining = seconds
        self.onFire = onFire
        let state = CountdownView.State(remaining: seconds)
        self.countState = state
        self.hostingView = NSHostingView(rootView: CountdownView(state: state))

        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        isReleasedWhenClosed = false

        contentView = hostingView

        let x = screen.frame.midX - 60
        let y = screen.frame.midY - 60
        setFrameOrigin(NSPoint(x: x, y: y))

        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        remaining -= 1
        countState.remaining = remaining
        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            close()
            onFire()
        }
    }
}

private struct CountdownView: View {
    @ObservedObject var state: State

    final class State: ObservableObject {
        @Published var remaining: Int
        init(remaining: Int) { self.remaining = remaining }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.6))
                .frame(width: 100, height: 100)

            Text("\(state.remaining)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: state.remaining)
        }
        .frame(width: 120, height: 120)
    }
}
