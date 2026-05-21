import AppKit
import NibikoCore
import SwiftUI

extension AppearanceMode {
    var appKitAppearance: NSAppearance? {
        switch self {
        case .system:
            return NSAppearance(named: systemUsesDarkAppearance ? .darkAqua : .aqua)
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return systemUsesDarkAppearance ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var systemUsesDarkAppearance: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}

@MainActor
func applyWindowAppearance(_ mode: AppearanceMode, to window: NSWindow?) {
    let appearance = mode.appKitAppearance
    window?.appearance = appearance
    window?.contentView?.appearance = appearance
    window?.contentViewController?.view.appearance = appearance
    window?.viewsNeedDisplay = true
    window?.contentView?.needsDisplay = true
    window?.contentViewController?.view.needsDisplay = true

    Task { @MainActor in
        window?.contentView?.layoutSubtreeIfNeeded()
        window?.contentView?.displayIfNeeded()
        window?.displayIfNeeded()
    }
}
