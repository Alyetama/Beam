// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Remote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Remote",
            path: "Sources/Remote"
        )
    ]
)
