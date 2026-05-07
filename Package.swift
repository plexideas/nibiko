// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuBarNotes",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MenuBarNotes", targets: ["MenuBarNotes"]),
        .library(name: "MenuBarNotesCore", targets: ["MenuBarNotesCore"])
    ],
    targets: [
        .target(
            name: "MenuBarNotesCore"
        ),
        .executableTarget(
            name: "MenuBarNotes",
            dependencies: ["MenuBarNotesCore"]
        ),
        .testTarget(
            name: "MenuBarNotesCoreTests",
            dependencies: ["MenuBarNotesCore"]
        )
    ]
)
