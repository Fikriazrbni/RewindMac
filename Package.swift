// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "RewindMac", platforms: [.macOS(.v14)],
    products: [.executable(name: "RewindMac", targets: ["RewindMac"]), .library(name: "RewindCore", targets: ["RewindCore"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "RewindCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "RewindMac", dependencies: ["RewindCore"]),
        .testTarget(name: "RewindCoreTests", dependencies: ["RewindCore"]),
        .testTarget(name: "RewindMacTests", dependencies: ["RewindMac", "RewindCore"])
    ], swiftLanguageModes: [.v6]
)
