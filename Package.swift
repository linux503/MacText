// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacText",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacText",
            path: "Sources/MacText"
        )
    ]
)
