import Foundation
import Testing
@testable import NibikoCore

@Suite("App information")
struct AppInfoTests {
    @Test("current app info includes compact dependency acknowledgement text")
    func appInfoIncludesDependencyNotice() {
        let appInfo = AppInfo.current(bundle: .main)

        #expect(!appInfo.acknowledgements.isEmpty)
    }
}
