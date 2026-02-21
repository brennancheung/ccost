// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CCost",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CCostLib",
            path: "Sources/CCostLib",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "ccost-cli",
            dependencies: ["CCostLib"],
            path: "Sources/ccost-cli"
        ),
        .executableTarget(
            name: "CCostBar",
            dependencies: ["CCostLib"],
            path: "Sources/CCostBar",
            resources: [.copy("Resources")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
)
