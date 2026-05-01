import AppKit
import ScreenCaptureKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let captureManager = ScreenCaptureManager()
    private let hotkeyManager = HotkeyManager()
    private let colorPicker = ColorPickerManager()
    private let timedCapture = TimedCaptureController()
    private let history = HistoryManager()
    private let exporter = ExportManager()
    private var editorWindows: Set<EditorWindow> = []
    private var pinWindows: Set<PinWindow> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        warmUpScreenCapturePermission()
        observeHotkeyChanges()
        hotkeyManager.register { [weak self] id in
            guard let self else { return }
            switch id {
            case 1: Task { await self.startAreaCapture() }
            case 2: Task { await self.captureFullScreen() }
            case 3: self.colorPicker.pick()
            case 4: Task { await self.startRuler() }
            case 5: Task { await self.captureWindow() }
            default: break
            }
        }
    }

    private func observeHotkeyChanges() {
        NotificationCenter.default.addObserver(
            forName: .hotkeyBindingChanged, object: nil, queue: .main
        ) { [weak self] note in
            guard let id = note.userInfo?["id"] as? UInt32,
                  let binding = note.userInfo?["binding"] as? HotkeyBinding else { return }
            Task { @MainActor [weak self] in
                self?.hotkeyManager.reconfigure(id: id, binding: binding)
            }
        }
    }

    private func warmUpScreenCapturePermission() {
        Task {
            _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        }
    }

    // MARK: – Menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Screenie"
        )
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Capture Area  ⌘⇧1", action: #selector(startAreaCaptureAction), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Fullscreen  ⌘⇧2", action: #selector(captureFullScreenAction), keyEquivalent: "")
        menu.addItem(withTitle: "Capture Window  ⌘⇧W", action: #selector(captureWindowAction), keyEquivalent: "")

        // Timed capture submenu
        let timedItem = NSMenuItem(title: "Timed Capture", action: nil, keyEquivalent: "")
        let timedMenu = NSMenu()
        for secs in [3, 5, 10] {
            let item = NSMenuItem(title: "After \(secs) seconds", action: #selector(timedCaptureAction(_:)), keyEquivalent: "")
            item.tag = secs
            timedMenu.addItem(item)
        }
        timedItem.submenu = timedMenu
        menu.addItem(timedItem)

        menu.addItem(withTitle: "Pixel Ruler  ⌥⇧R", action: #selector(startRulerAction), keyEquivalent: "")
        menu.addItem(withTitle: "Pick Color  ⌥⇧C", action: #selector(pickColorAction), keyEquivalent: "")
        menu.addItem(.separator())

        // History submenu
        let historyItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        historyItem.submenu = buildHistoryMenu()
        menu.addItem(historyItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Screenie", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func buildHistoryMenu() -> NSMenu {
        let menu = NSMenu()
        if history.records.isEmpty {
            menu.addItem(withTitle: "No recent captures", action: nil, keyEquivalent: "")
            return menu
        }
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        for record in history.records.prefix(10) {
            let title = fmt.string(from: record.date)
            let item = NSMenuItem(title: title, action: #selector(openHistoryRecord(_:)), keyEquivalent: "")
            item.representedObject = record.id.uuidString
            if let thumb = record.thumbnail {
                let img = thumb.copy() as! NSImage
                img.size = NSSize(width: 32, height: 20)
                item.image = img
            }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        return menu
    }

    // MARK: – Actions

    @objc private func startAreaCaptureAction() { Task { await startAreaCapture() } }
    @objc private func captureFullScreenAction() { Task { await captureFullScreen() } }
    @objc private func captureWindowAction() { Task { await captureWindow() } }
    @objc private func pickColorAction() { colorPicker.pick() }
    @objc private func startRulerAction() { Task { await startRuler() } }

    @objc private func timedCaptureAction(_ sender: NSMenuItem) {
        let secs = sender.tag
        timedCapture.countdownThenCapture(seconds: secs) { [weak self] in
            await self?.startAreaCapture()
        }
    }

    @objc private func openHistoryRecord(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let record = history.records.first(where: { $0.id == id }),
              let image = record.thumbnail else { return }
        openEditor(with: image)
    }

    @objc private func clearHistory() { history.clearAll(); rebuildMenu() }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func rebuildMenu() { statusItem.menu = buildMenu() }

    // MARK: – Capture flows

    private func startAreaCapture() async {
        let overlay = MultiDisplayOverlay()
        guard let result = await overlay.selectArea() else { return }
        try? await Task.sleep(for: .milliseconds(150))
        guard let image = await captureManager.captureArea(result.rect, displayID: result.displayID) else { return }
        deliver(image)
    }

    private func captureFullScreen() async {
        guard let image = await captureManager.captureFullScreen() else { return }
        deliver(image)
    }

    private func captureWindow() async {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return }
        let picker = WindowCaptureOverlay()
        guard let scWindow = await picker.selectWindow(from: content) else { return }
        try? await Task.sleep(for: .milliseconds(150))

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width * 2)
        config.height = Int(scWindow.frame.height * 2)
        config.showsCursor = false

        guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return }
        let image = NSImage(cgImage: cgImage, size: scWindow.frame.size)
        deliver(image)
    }

    private func startRuler() async {
        let ruler = RulerOverlayWindow()
        guard let pixels = await ruler.measure() else { return }
        let msg = "\(Int(pixels)) px"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(msg, forType: .string)
        showRulerResult(msg)
    }

    /// Routes a fresh capture to clipboard, Desktop, custom folder, or editor based on settings.
    private func deliver(_ image: NSImage) {
        history.add(image)
        rebuildMenu()

        switch AppSettings.shared.saveDestination {
        case .clipboard:
            openEditor(with: image)
        case .desktop:
            let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            autoSave(image, to: url)
            openEditor(with: image)
        case .custom:
            if let url = AppSettings.shared.customSaveURL {
                autoSave(image, to: url)
            }
            openEditor(with: image)
        }
    }

    private func autoSave(_ image: NSImage, to directory: URL) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let name = "Screenshot \(fmt.string(from: Date())).png"
        let url = directory.appendingPathComponent(name)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    func openEditor(with image: NSImage) {
        let window = EditorWindow(image: image) { [weak self] pinImage in
            guard let self else { return }
            let pin = PinWindow(image: pinImage)
            pin.makeKeyAndOrderFront(nil)
            self.pinWindows.insert(pin)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindows.insert(window)
    }

    private func showRulerResult(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Measurement"
        alert.informativeText = "\(text) — copied to clipboard"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
