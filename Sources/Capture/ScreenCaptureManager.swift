import ScreenCaptureKit
import AppKit

@MainActor
final class ScreenCaptureManager {
    private func shareableContent() async -> SCShareableContent? {
        try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    func captureArea(_ rect: CGRect, displayID: CGDirectDisplayID) async -> NSImage? {
        guard let content = await shareableContent(),
              let display = content.displays.first(where: { $0.displayID == displayID })
                            ?? content.displays.first else { return nil }

        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let scaleFactor = screen.backingScaleFactor
        let filter = SCContentFilter(
            display: display,
            excludingApplications: selfApp(from: content).map { [$0] } ?? [],
            exceptingWindows: []
        )

        // sourceRect is relative to the display's top-left corner
        let displayOrigin = screen.frame.origin
        let localRect = CGRect(
            x: rect.minX - displayOrigin.x,
            y: rect.minY - displayOrigin.y,
            width: rect.width,
            height: rect.height
        )

        let config = SCStreamConfiguration()
        config.sourceRect = localRect
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.showsCursor = false

        return await capture(filter: filter, config: config, pointSize: rect.size)
    }

    func captureFullScreen(on screen: NSScreen? = nil) async -> NSImage? {
        guard let content = await shareableContent() else { return nil }
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let targetID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == targetID })
                            ?? content.displays.first else { return nil }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: selfApp(from: content).map { [$0] } ?? [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false

        let pointSize = CGSize(
            width: CGFloat(display.width) / targetScreen.backingScaleFactor,
            height: CGFloat(display.height) / targetScreen.backingScaleFactor
        )
        return await capture(filter: filter, config: config, pointSize: pointSize)
    }

    private func capture(
        filter: SCContentFilter,
        config: SCStreamConfiguration,
        pointSize: CGSize
    ) async -> NSImage? {
        guard let cgImage = try? await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        ) else { return nil }
        return NSImage(cgImage: cgImage, size: pointSize)
    }

    private func selfApp(from content: SCShareableContent) -> SCRunningApplication? {
        content.applications.first { $0.bundleIdentifier == "com.screenie.app" }
    }
}
