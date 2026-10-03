// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacANotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacANotch",
            path: "Sources/MacANotch"
        )
    ]
)
