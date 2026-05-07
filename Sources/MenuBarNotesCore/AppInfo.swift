import Foundation

public struct AppInfo: Equatable, Sendable {
    public var name: String
    public var version: String
    public var build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    public static func current(bundle: Bundle = .main, fallbackName: String = "Menu Bar Notes") -> AppInfo {
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fallbackName
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "dev"

        return AppInfo(name: name, version: version, build: build)
    }
}
