import Carbon

@MainActor
final class GlobalHotKey {
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    nonisolated(unsafe) private static var instance: GlobalHotKey?

    init(keyCode: UInt32, modifiers: UInt32, action: @MainActor @escaping () -> Void) {
        self.action = action
        GlobalHotKey.instance = self
        register(keyCode: keyCode, modifiers: modifiers)
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4343_4F53) // "CCOS"
        hotKeyID.id = 1

        let eventSpec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            guard status == noErr else { return status }

            Task { @MainActor in
                GlobalHotKey.instance?.action()
            }
            return noErr
        }

        var handlerRefOut: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            eventSpec.count,
            eventSpec,
            nil,
            &handlerRefOut
        )
        self.handlerRef = handlerRefOut

        var hotKeyRefOut: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRefOut)
        self.hotKeyRef = hotKeyRefOut
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
        if GlobalHotKey.instance === self {
            GlobalHotKey.instance = nil
        }
    }

    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
        }
    }
}
