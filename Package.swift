// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftClaw",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftClawCore", targets: ["SwiftClawCore"]),
        .library(name: "SwiftClawMLX", targets: ["SwiftClawMLX"]),
        .library(name: "SwiftClawHTTP", targets: ["SwiftClawHTTP"]),
        .library(name: "SwiftClawTools", targets: ["SwiftClawTools"]),
        .library(name: "SwiftClawPippin", targets: ["SwiftClawPippin"]),
        .executable(name: "swiftclaw", targets: ["swiftclaw"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.30.6"),
    ],
    targets: [
        .target(name: "SwiftClawCore"),
        .target(name: "SwiftClawHTTP", dependencies: ["SwiftClawCore"]),
        .target(name: "SwiftClawMLX", dependencies: [
            "SwiftClawCore",
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXOptimizers", package: "mlx-swift"),
        ]),
        .target(name: "SwiftClawTools", dependencies: ["SwiftClawCore"]),
        .target(name: "SwiftClawPippin", dependencies: ["SwiftClawCore"]),
        .executableTarget(name: "swiftclaw", dependencies: [
            "SwiftClawCore", "SwiftClawMLX", "SwiftClawHTTP", "SwiftClawTools", "SwiftClawPippin",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftClawCoreTests", dependencies: ["SwiftClawCore"]),
        .testTarget(name: "SwiftClawHTTPTests", dependencies: ["SwiftClawHTTP"]),
        .testTarget(name: "SwiftClawToolsTests", dependencies: ["SwiftClawTools"]),
        .testTarget(name: "SwiftClawMLXTests", dependencies: ["SwiftClawMLX"]),
        .testTarget(name: "SwiftClawPippinTests", dependencies: ["SwiftClawPippin"]),
    ]
)
