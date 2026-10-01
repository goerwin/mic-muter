// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicMuter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MicMuterCore", targets: ["MicMuterCore"])
    ],
    targets: [
        // Keep the non-UI implementation buildable by SwiftPM for unit tests.
        .target(
            name: "MicMuterCore",
            path: "Sources/MicMuter",
            exclude: ["App", "UI", "Services/System/KeyboardShortcutService.swift"],
            sources: ["State", "Features", "Services", "Audio"]
        ),
        .testTarget(name: "MicMuterCoreTests", dependencies: ["MicMuterCore"]),
    ]
)
