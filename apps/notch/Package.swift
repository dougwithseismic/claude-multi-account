// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeNotch",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UsageCore", targets: ["UsageCore"]),
        .executable(name: "claude-usage", targets: ["claude-usage"]),
        .executable(name: "ClaudeNotch", targets: ["ClaudeNotch"]),
        .executable(name: "claude-chrome-relay", targets: ["claude-chrome-relay"]),
    ],
    targets: [
        .target(name: "UsageCore"),
        .target(name: "ChromeRelay"),
        .executableTarget(name: "claude-usage", dependencies: ["UsageCore"]),
        .executableTarget(name: "ClaudeNotch", dependencies: ["UsageCore"]),
        .executableTarget(name: "claude-chrome-relay", dependencies: ["ChromeRelay", "UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
        .testTarget(name: "ClaudeNotchTests", dependencies: ["ClaudeNotch"]),
        .testTarget(name: "ChromeRelayTests", dependencies: ["ChromeRelay"]),
    ]
)
