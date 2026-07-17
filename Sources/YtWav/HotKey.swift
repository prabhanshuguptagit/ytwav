import Carbon.HIToolbox
import Foundation

/// System-wide hotkey via Carbon's RegisterEventHotKey — works while the app
/// is in the background and needs no accessibility permissions (unlike
/// NSEvent global monitors). Same approach as sondd.
final class GlobalHotKey {
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Default: ⇧⌘Y.
    init(keyCode: UInt32 = UInt32(kVK_ANSI_Y),
         modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { me.onPress?() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x59_54_57_56), id: 1) // "YTWV"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
