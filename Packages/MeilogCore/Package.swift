// swift-tools-version: 6.0
// MeilogCore: import Foundation のみ。dependencies は空のまま保つこと
import PackageDescription

let package = Package(
    name: "MeilogCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),   // macOS 上で `swift test` を回すため
    ],
    products: [
        .library(name: "MeilogCore", targets: ["MeilogCore"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "MeilogCore"),
        .testTarget(name: "MeilogCoreTests", dependencies: ["MeilogCore"]),
    ]
)
