// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YtWav",
    platforms: [.macOS("14.0")],
    targets: [
        .executableTarget(
            name: "YtWav",
            path: "Sources/YtWav",
            linkerSettings: [
                .linkedFramework("Carbon") // RegisterEventHotKey (global ⇧⌘Y)
            ]
        )
    ]
)
