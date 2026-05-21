import Testing
@testable import NibikoCore

@Suite("Hotkey binding")
struct HotkeyBindingTests {
    @Test("registration status mapper distinguishes disabled, registered, conflict, and failed")
    func mapsRegistrationStatus() {
        let binding = HotkeyBinding.default

        #expect(
            HotkeyRegistrationStatusMapper.status(
                for: .disabled,
                registrationResult: 0,
                conflictCodes: [-9878]
            ) == .disabled
        )
        #expect(
            HotkeyRegistrationStatusMapper.status(
                for: binding,
                registrationResult: 0,
                conflictCodes: [-9878]
            ) == .registered(binding)
        )
        #expect(
            HotkeyRegistrationStatusMapper.status(
                for: binding,
                registrationResult: -9878,
                conflictCodes: [-9878]
            ) == .conflict(binding)
        )
        #expect(
            HotkeyRegistrationStatusMapper.status(
                for: binding,
                registrationResult: -50,
                conflictCodes: [-9878]
            ) == .failed(binding)
        )
    }

    @Test("display strings keep configured shortcuts readable")
    func displayString() {
        #expect(HotkeyBinding.default.displayString == "Option-Command-N")
        #expect(HotkeyBinding.controlOptionSpace.displayString == "Control-Option-Space")
    }
}
