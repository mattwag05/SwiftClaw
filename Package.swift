// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftClaw",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftClawCore", targets: ["SwiftClawCore"]),
        .library(name: "SwiftClawMLX", targets: ["SwiftClawMLX"]),
        .library(name: "SwiftClawTools", targets: ["SwiftClawTools"]),
        .executable(name: "swiftclaw", targets: ["swiftclaw"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.1"),
    ],
    targets: [
        .target(name: "SwiftClawCore"),
        .target(name: "SwiftClawMLX", dependencies: [
            "SwiftClawCore",
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
        ]),
        .target(name: "SwiftClawTools", dependencies: ["SwiftClawCore"]),
        .executableTarget(name: "swiftclaw", dependencies: [
            "SwiftClawCore", "SwiftClawMLX", "SwiftClawTools",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftClawCoreTests", dependencies: ["SwiftClawCore"]),
        .testTarget(name: "SwiftClawToolsTests", dependencies: ["SwiftClawTools"]),
        .testTarget(name: "SwiftClawMLXTests", dependencies: ["SwiftClawMLX"]),
    ]
)
