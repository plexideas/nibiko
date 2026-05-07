import Carbon
import Combine
import Foundation
import MenuBarNotesCore

@MainActor
final class GlobalHotkeyRegistrar: ObservableObject {
    @Published private(set) var status: HotkeyRegistrationStatus = .disabled

    private let onPressed: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(onPressed: @escaping @MainActor () -> Void) {
        self.onPressed = onPressed
    }

    func register(_ binding: HotkeyBinding) {
        unregisterCurrentHotkey()

        guard binding.isEnabled else {
            status = .disabled
            return
        }

        let handlerStatus = installEventHandlerIfNeeded()
        guard handlerStatus == noErr else {
            status = .failed(binding)
            return
        }

        var nextHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registrationStatus = RegisterEventHotKey(
            binding.keyCode,
            carbonModifierFlags(for: binding.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &nextHotKeyRef
        )

        status = HotkeyRegistrationStatusMapper.status(
            for: binding,
            registrationResult: registrationStatus,
            conflictCodes: [Int32(eventHotKeyExistsErr)]
        )

        if registrationStatus == noErr {
            hotKeyRef = nextHotKeyRef
        }
    }

    private func handlePressedHotkey() {
        onPressed()
    }

    private func installEventHandlerIfNeeded() -> OSStatus {
        guard eventHandlerRef == nil else {
            return noErr
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        return InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func unregisterCurrentHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func carbonModifierFlags(for modifiers: HotkeyModifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            flags |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        return flags
    }

    private static let signature: OSType = {
        "MBNQ".utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }()

    private static let eventHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else {
            return noErr
        }

        let registrar = Unmanaged<GlobalHotkeyRegistrar>
            .fromOpaque(userData)
            .takeUnretainedValue()
        Task { @MainActor in
            registrar.handlePressedHotkey()
        }
        return noErr
    }
}
