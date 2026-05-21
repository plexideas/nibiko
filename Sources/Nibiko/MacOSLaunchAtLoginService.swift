import NibikoCore
import ServiceManagement

@MainActor
final class MacOSLaunchAtLoginService: LaunchAtLoginServicing {
    func setLaunchAtLoginEnabled(_ isEnabled: Bool) throws {
        let service = SMAppService.mainApp

        switch service.status {
        case .enabled:
            if !isEnabled {
                try service.unregister()
            }
        case .notRegistered:
            if isEnabled {
                try service.register()
            }
        case .notFound:
            if isEnabled {
                try service.register()
            }
        default:
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        }
    }
}
