// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nibiko",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Nibiko", targets: ["Nibiko"]),
        .library(name: "NibikoCore", targets: ["NibikoCore"])
    ],
    targets: [
        .target(
            name: "NibikoCore"
        ),
        .executableTarget(
            name: "Nibiko",
            dependencies: ["NibikoCore"]
        ),
        .testTarget(
            name: "NibikoCoreTests",
            dependencies: ["NibikoCore"]
        )
    ]
)
