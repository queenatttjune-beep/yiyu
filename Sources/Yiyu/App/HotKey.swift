import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut via Carbon's hot key API, which needs no
/// Accessibility permission.
@MainActor
final class HotKey {
    private static let signature: OSType = 0x5949_5955  // "YIYU"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    /// Returns nil when another app already owns the shortcut.
    init?(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, context, &handlerRef
        )
        guard installStatus == noErr else {
            NSLog("Yiyu: installing the hot key handler failed (%d)", installStatus)
            return nil
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registerStatus == noErr else {
            NSLog("Yiyu: registering the hot key failed (%d); another app may be using it", registerStatus)
            RemoveEventHandler(handlerRef)
            return nil
        }
    }

    fileprivate func fire() {
        action()
    }
}

private func hotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { hotKey.fire() }
    return noErr
}
