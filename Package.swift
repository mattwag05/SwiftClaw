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
        .executable(name: "swiftclaw", targets: ["swiftclaw"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", revision: "3a7f2b189f9001ec86a9a09ffaf553e28c4320ea"),
    ],
    targets: [
        .target(name: "SwiftClawCore"),
        .target(name: "SwiftClawHTTP", dependencies: ["SwiftClawCore"]),
        .target(name: "SwiftClawMLX", dependencies: [
            "SwiftClawCore",
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
        ]),
        .target(name: "SwiftClawTools", dependencies: ["SwiftClawCore"]),
        .executableTarget(name: "swiftclaw", dependencies: [
            "SwiftClawCore", "SwiftClawMLX", "SwiftClawHTTP", "SwiftClawTools",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftClawCoreTests", dependencies: ["SwiftClawCore"]),
        .testTarget(name: "SwiftClawHTTPTests", dependencies: ["SwiftClawHTTP"]),
        .testTarget(name: "SwiftClawToolsTests", dependencies: ["SwiftClawTools"]),
        .testTarget(name: "SwiftClawMLXTests", dependencies: ["SwiftClawMLX"]),
    ]
)
