// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicMuter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MicMuterCore", targets: ["MicMuterCore"])
    ],
    targets: [
        .target(
            name: "MicMuterCore",
            path: "Sources/MicMuter",
            exclude: ["App", "UI", "Services/System/KeyboardShortcutService.swift"],
            sources: ["State", "Features", "Services", "Audio"]
        ),
        .testTarget(name: "MicMuterCoreTests", dependencies: ["MicMuterCore"]),
    ]
)
