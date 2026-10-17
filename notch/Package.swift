// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeNotch",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UsageCore", targets: ["UsageCore"]),
        .executable(name: "claude-usage", targets: ["claude-usage"]),
    ],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "claude-usage", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
    ]
)
