import AppKit
import SwiftUI

@MainActor
final class CaptureOverlayWindow: NSWindow {
    private var continuation: CheckedContinuation<CGRect?, Never>?
    private var keyMonitor: Any?
    let targetScreen: NSScreen

    init(screen: NSScreen) {
        self.targetScreen = screen
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
        ignoresMouseEvents = false

        contentView = NSHostingView(rootView: CaptureOverlayView { [weak self] rect in
            self?.finish(rect)
        })
    }

    func selectArea() async -> CGRect? {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil); return nil }
            return event
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()

        return await withCheckedContinuation { self.continuation = $0 }
    }

    func cancel() {
        finish(nil)
    }

    private func finish(_ rect: CGRect?) {
        NSCursor.pop()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        orderOut(nil)
        continuation?.resume(returning: rect)
        continuation = nil
    }
}

// Spans all displays; returns the selected rect and the display ID it was drawn on.
@MainActor
final class MultiDisplayOverlay {
    private var windows: [CaptureOverlayWindow] = []

    func selectArea() async -> (rect: CGRect, displayID: CGDirectDisplayID)? {
        return await withCheckedContinuation { continuation in
            var resumed = false

            for screen in NSScreen.screens {
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
                let screenScale = screen.backingScaleFactor
                let snapshot = CGDisplayCreateImage(displayID)

                let window = CaptureOverlayWindow(screen: screen)
                windows.append(window)

                window.contentView = NSHostingView(rootView: CaptureOverlayView(
                    onSelect: { [weak self] rect in
                        guard !resumed else { return }
                        resumed = true
                        self?.closeAll()
                        if let rect {
                            continuation.resume(returning: (rect, displayID))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    },
                    screenImage: snapshot,
                    screenScale: screenScale
                ))
            }

            // Register a single ESC monitor that cancels everything
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53, !resumed {
                    resumed = true
                    self?.closeAll()
                    continuation.resume(returning: nil)
                    return nil
                }
                return event
            }

            for window in windows {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            NSCursor.crosshair.push()

            // Retain monitor until cancelled — stored via objc association on self
            objc_setAssociatedObject(self, &MultiDisplayOverlay.monitorKey, monitor, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private static var monitorKey = 0

    private func closeAll() {
        NSCursor.pop()
        if let monitor = objc_getAssociatedObject(self, &MultiDisplayOverlay.monitorKey) {
            NSEvent.removeMonitor(monitor)
            objc_setAssociatedObject(self, &MultiDisplayOverlay.monitorKey, nil, .OBJC_ASSOCIATION_RETAIN)
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
