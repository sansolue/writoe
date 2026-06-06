// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Writoe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Writoe",
            path: "Sources/Writoe"
        )
    ]
)
