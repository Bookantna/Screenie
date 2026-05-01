import AppKit
import SwiftUI

@MainActor
final class ColorPickerManager {
    private var resultWindow: NSWindow?

    func pick() {
        let sampler = NSColorSampler()
        sampler.show { [weak self] color in
            guard let self, let color else { return }
            Task { @MainActor in self.showResult(color) }
        }
    }

    private func showResult(_ color: NSColor) {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        let hex = String(format: "#%02X%02X%02X", r, g, b)

        let panel = ColorResultPanel(hex: hex, rgb: "rgb(\(r), \(g), \(b))", nsColor: color)
        let hosting = NSHostingView(rootView: panel)
        hosting.frame = CGRect(x: 0, y: 0, width: 240, height: 96)

        let window = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 240, height: 96),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "Color"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        resultWindow = window
    }
}

private struct ColorResultPanel: View {
    let hex: String
    let rgb: String
    let nsColor: NSColor
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: nsColor))
                .frame(width: 56, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(hex)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Text(rgb)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button(copied ? "Copied!" : "Copy Hex") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hex, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(16)
    }
}
