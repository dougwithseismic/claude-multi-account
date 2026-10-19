import Carbon.HIToolbox
import Foundation
import UsageCore

/// ⌥⌘ + a profile's key, system-wide. Carbon's hotkeys need no Accessibility permission.
@MainActor
final class Hotkeys {
    private static var actions: [UInt32: () -> Void] = [:]
    private var registered: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    /// Registers ⌥⌘`key` for each binding, replacing any earlier ones. Returns the keys that
    /// couldn't be registered (unknown, or already taken by another app).
    @discardableResult
    func register(_ bindings: [(key: String, action: () -> Void)]) -> [String] {
        unregister()
        installHandler()
        var failed: [String] = []
        for (index, binding) in bindings.enumerated() {
            guard let code = Self.keyCode(for: binding.key) else {
                failed.append(binding.key)
                continue
            }
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(code), UInt32(cmdKey | optionKey), EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(), 0, &ref
            )
            guard status == noErr, let ref else {
                failed.append(binding.key)
                continue
            }
            registered.append(ref)
            Self.actions[id] = binding.action
        }
        return failed
    }

    func unregister() {
        registered.forEach { UnregisterEventHotKey($0) }
        registered = []
        Self.actions = [:]
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr, id.signature == Hotkeys.signature else { return OSStatus(eventNotHandledErr) }
            // The application event target delivers on the main thread.
            MainActor.assumeIsolated { Hotkeys.actions[id.id]?() }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    nonisolated static let signature: OSType = 0x434E_7463 // "CNtc"

    /// The virtual key code for "1" or "B", or nil.
    nonisolated static func keyCode(for key: String) -> Int? {
        guard key.count == 1, let c = key.uppercased().first else { return nil }
        return keyCodes[c]
    }

    nonisolated private static let keyCodes: [Character: Int] = [
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E,
        "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J,
        "K": kVK_ANSI_K, "L": kVK_ANSI_L, "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O,
        "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
        "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X, "Y": kVK_ANSI_Y,
        "Z": kVK_ANSI_Z,
    ]
}

/// Which ⌥⌘ key does what: each profile's own key, then ⌥⌘0 for the copy with the most
/// room, unless that's switched off or a profile has 0 for its own.
enum HotkeyPlan {
    enum Target: Equatable {
        case copy(String)
        case mostRoom
    }

    static let mostRoomKey = "0"

    static func bindings(_ styles: [ProfileStyle], mostRoom: Bool) -> [(key: String, target: Target)] {
        var plan = styles.compactMap { style in style.hotkey.map { (key: $0, target: Target.copy(style.letter)) } }
        if mostRoom, mostRoomKeyOwner(styles) == nil { plan.append((key: mostRoomKey, target: .mostRoom)) }
        return plan
    }

    /// The profile whose own key is 0, if any: ⌥⌘0 is then its.
    static func mostRoomKeyOwner(_ styles: [ProfileStyle]) -> String? {
        styles.first { $0.hotkey == mostRoomKey }?.letter
    }
}
