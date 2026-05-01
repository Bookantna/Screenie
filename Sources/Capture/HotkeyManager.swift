import Carbon
import AppKit

// MARK: – Binding model

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier mask

    static let defaults: [UInt32: HotkeyBinding] = [
        1: .init(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey)),
        2: .init(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey)),
        3: .init(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey | shiftKey)),
        4: .init(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(optionKey | shiftKey)),
        5: .init(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(cmdKey | shiftKey)),
    ]

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += Self.keySymbol(keyCode)
        return s
    }

    static func keySymbol(_ code: UInt32) -> String {
        let table: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        ]
        return table[code] ?? "?"
    }

    // Convert NSEvent modifiers → Carbon mask
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }
}

// MARK: – Manager

private nonisolated(unsafe) var _hotkeyCallback: ((UInt32) -> Void)?

@MainActor
final class HotkeyManager {
    private nonisolated(unsafe) var refs: [UInt32: EventHotKeyRef] = [:]
    private nonisolated(unsafe) var eventHandlerRef: EventHandlerRef?

    func register(callback: @escaping @MainActor (UInt32) -> Void) {
        _hotkeyCallback = { id in Task { @MainActor in callback(id) } }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            _hotkeyCallback?(hkID.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, &eventHandlerRef)

        for id: UInt32 in [1, 2, 3, 4, 5] {
            let binding = AppSettings.shared.binding(for: id)
            registerHotKey(id: id, binding: binding)
        }
    }

    func reconfigure(id: UInt32, binding: HotkeyBinding) {
        if let old = refs[id] { UnregisterEventHotKey(old); refs[id] = nil }
        AppSettings.shared.setBinding(binding, for: id)
        registerHotKey(id: id, binding: binding)
    }

    private func registerHotKey(id: UInt32, binding: HotkeyBinding) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: 0x5343524E, id: id)
        RegisterEventHotKey(binding.keyCode, binding.modifiers, hkID,
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs[id] = ref }
    }

    deinit {
        refs.values.forEach { UnregisterEventHotKey($0) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
