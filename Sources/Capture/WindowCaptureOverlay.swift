import AppKit
import SwiftUI
import ScreenCaptureKit

@MainActor
final class WindowCaptureOverlay {
    private var overlayWindow: NSWindow?
    private var continuation: CheckedContinuation<CGWindowID?, Never>?
    private var keyMonitor: Any?

    // Returns the CGWindowID of the selected window, or nil if cancelled.
    func selectWindow(from content: SCShareableContent) async -> SCWindow? {
        let onScreen = content.windows.filter {
            $0.isOnScreen && $0.frame.width > 10 && $0.frame.height > 10
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]

        let windowID: CGWindowID? = await withCheckedContinuation { cont in
            self.continuation = cont

            let view = WindowPickerView(
                windows: onScreen,
                screen: screen,
                onPick: { [weak self] wid in self?.finish(wid) },
                onCancel: { [weak self] in self?.finish(nil) }
            )
            let win = NSWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false
            )
            win.level = .screenSaver
            win.isOpaque = false
            win.backgroundColor = .clear
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.hasShadow = false
            win.contentView = NSHostingView(rootView: view)
            self.overlayWindow = win

            self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.finish(nil); return nil }
                return event
            }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSCursor.arrow.push()
        }

        guard let wid = windowID else { return nil }
        return content.windows.first { $0.windowID == wid }
    }

    private func finish(_ windowID: CGWindowID?) {
        NSCursor.pop()
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        continuation?.resume(returning: windowID)
        continuation = nil
    }
}

// MARK: – SwiftUI overlay

private struct WindowInfo {
    let windowID: CGWindowID
    let frame: CGRect
    let title: String?
}

private struct WindowPickerView: View {
    let windows: [SCWindow]
    let screen: NSScreen
    let onPick: (CGWindowID) -> Void
    let onCancel: () -> Void

    @State private var hoveredID: CGWindowID?

    private var infos: [WindowInfo] {
        windows.map { WindowInfo(windowID: $0.windowID, frame: $0.frame, title: $0.title) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.2)

                ForEach(infos, id: \.windowID) { info in
                    let rect = viewRect(quartz: info.frame, screenHeight: geo.size.height)
                    if hoveredID == info.windowID {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)

                        if let title = info.title, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                                .position(x: rect.midX, y: max(rect.minY - 14, 16))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard case .active(let loc) = phase else { hoveredID = nil; return }
                hoveredID = infos.first {
                    viewRect(quartz: $0.frame, screenHeight: geo.size.height).contains(loc)
                }?.windowID
            }
            .onTapGesture { loc in
                if let info = infos.first(where: {
                    viewRect(quartz: $0.frame, screenHeight: geo.size.height).contains(loc)
                }) {
                    onPick(info.windowID)
                }
            }
        }
        .ignoresSafeArea()
    }

    // Quartz (bottom-left origin) → SwiftUI (top-left origin)
    private func viewRect(quartz f: CGRect, screenHeight: CGFloat) -> CGRect {
        let origin = screen.frame.origin
        return CGRect(
            x: f.minX - origin.x,
            y: screenHeight - (f.maxY - origin.y),
            width: f.width, height: f.height
        )
    }
}
