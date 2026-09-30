// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicMuterState",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MicMuterState", targets: ["MicMuterState"])
    ],
    targets: [
        .target(name: "MicMuterState", path: "Sources/MicMuter/State"),
        .testTarget(name: "MicMuterStateTests", dependencies: ["MicMuterState"]),
    ]
)
