// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "yabai-dockstack",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "YabaiDockstackKit"),
        .executableTarget(
            name: "yabai-dockstack",
            dependencies: ["YabaiDockstackKit"]
        ),
        .executableTarget(
            name: "yst-selftest",
            dependencies: ["YabaiDockstackKit"]
        ),
        .testTarget(
            name: "YabaiDockstackKitTests",
            dependencies: ["YabaiDockstackKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
