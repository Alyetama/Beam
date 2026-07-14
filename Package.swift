// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Beam",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Beam",
            path: "Sources/Beam"
        )
    ]
)
