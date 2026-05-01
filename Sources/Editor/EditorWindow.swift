import AppKit
import SwiftUI

@MainActor
final class EditorWindow: NSWindow, @unchecked Sendable {
    init(image: NSImage, onPin: @escaping @MainActor (NSImage) -> Void) {
        let canvasSize = Self.canvasSize(for: image)
        let windowSize = CGSize(
            width: canvasSize.width,
            height: canvasSize.height + 44 + 52  // toolbar + action bar
        )

        super.init(
            contentRect: CGRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = "Screenie — Editor"
        isReleasedWhenClosed = false

        contentView = NSHostingView(rootView: EditorView(
            image: image,
            onClose: { [weak self] in self?.close() },
            onPin: onPin
        ))

        center()
    }

    static func canvasSize(for image: NSImage) -> CGSize {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let maxW = screen.visibleFrame.width * 0.8
        let maxH = screen.visibleFrame.height * 0.8
        let scale = min(maxW / image.size.width, maxH / image.size.height, 1.0)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}
