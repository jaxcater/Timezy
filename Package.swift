// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimezyCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "TimezyCore", targets: ["TimezyCore"])],
    targets: [
        .target(name: "TimezyCore", path: "Sources/Core"),
        .testTarget(name: "TimezyCoreTests", dependencies: ["TimezyCore"], path: "Tests/TimezyCoreTests")
    ]
)
