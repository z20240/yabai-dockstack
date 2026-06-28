// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "yabai-stackline",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "YabaiStacklineKit"),
        .executableTarget(
            name: "yabai-stackline",
            dependencies: ["YabaiStacklineKit"]
        ),
        .executableTarget(
            name: "yst-selftest",
            dependencies: ["YabaiStacklineKit"]
        ),
        .testTarget(
            name: "YabaiStacklineKitTests",
            dependencies: ["YabaiStacklineKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
