import AppKit
import SwiftUI

@MainActor
final class PinWindow: NSPanel {
    init(image: NSImage) {
        let size = Self.displaySize(for: image)
        super.init(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = true
        isReleasedWhenClosed = false

        contentView = NSHostingView(rootView: PinView(image: image) { [weak self] in
            self?.close()
        })
        center()
    }

    private static func displaySize(for image: NSImage) -> CGSize {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let maxW = screen.visibleFrame.width * 0.5
        let maxH = screen.visibleFrame.height * 0.5
        let scale = min(maxW / image.size.width, maxH / image.size.height, 1.0)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}

private struct PinView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if isHovering {
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}
