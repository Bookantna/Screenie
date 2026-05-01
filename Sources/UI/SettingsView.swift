import SwiftUI
import AppKit
import Carbon

// MARK: – Destinations

enum SaveDestination: String, CaseIterable {
    case clipboard = "Clipboard only"
    case desktop   = "Desktop"
    case custom    = "Custom folder…"
}

// MARK: – AppSettings

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var saveDestination: SaveDestination {
        get { SaveDestination(rawValue: UserDefaults.standard.string(forKey: "saveDestination") ?? "") ?? .clipboard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "saveDestination") }
    }

    var customSaveURL: URL? {
        get {
            guard let bookmark = UserDefaults.standard.data(forKey: "customSaveBookmark") else { return nil }
            var stale = false
            return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                            relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        set {
            let data = try? newValue?.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: "customSaveBookmark")
        }
    }

    func binding(for id: UInt32) -> HotkeyBinding {
        let key = "hotkey_\(id)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let b = try? JSONDecoder().decode(HotkeyBinding.self, from: data) else {
            return HotkeyBinding.defaults[id] ?? .init(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey))
        }
        return b
    }

    func setBinding(_ binding: HotkeyBinding, for id: UInt32) {
        guard let data = try? JSONEncoder().encode(binding) else { return }
        UserDefaults.standard.set(data, forKey: "hotkey_\(id)")
    }
}

// MARK: – Settings view

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var customFolderName = AppSettings.shared.customSaveURL?.lastPathComponent ?? "Not set"

    var body: some View {
        Form {
            Section("Shortcuts") {
                HotkeyRow(id: 1, label: "Capture Area")
                HotkeyRow(id: 2, label: "Capture Fullscreen")
                HotkeyRow(id: 3, label: "Pick Color")
                HotkeyRow(id: 4, label: "Pixel Ruler")
            }

            Section("After Capture") {
                Picker("Save to", selection: $settings.saveDestination) {
                    ForEach(SaveDestination.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.saveDestination) { _, new in
                    if new == .custom { pickFolder() }
                }

                if settings.saveDestination == .custom {
                    HStack {
                        Text(customFolderName).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button("Change…") { pickFolder() }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else {
            if settings.saveDestination == .custom && settings.customSaveURL == nil {
                settings.saveDestination = .clipboard
            }
            return
        }
        settings.customSaveURL = url
        customFolderName = url.lastPathComponent
    }
}

// MARK: – Hotkey recorder row

private struct HotkeyRow: View {
    let id: UInt32
    let label: String

    @State private var binding = AppSettings.shared.binding(for: 0)
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        LabeledContent(label) {
            Button(isRecording ? "Press keys…" : binding.displayString) {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(isRecording ? .red : .primary)
            .onAppear { binding = AppSettings.shared.binding(for: id) }
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode != UInt16(kVK_Escape) else {
                self.stopRecording(); return nil
            }
            let carbonMods = HotkeyBinding.carbonModifiers(from: event.modifierFlags)
            guard carbonMods != 0 else { return event } // require at least one modifier
            let newBinding = HotkeyBinding(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
            self.binding = newBinding
            // Post to AppDelegate's HotkeyManager via notification
            NotificationCenter.default.post(
                name: .hotkeyBindingChanged,
                object: nil,
                userInfo: ["id": self.id, "binding": newBinding]
            )
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

extension Notification.Name {
    static let hotkeyBindingChanged = Notification.Name("hotkeyBindingChanged")
}
