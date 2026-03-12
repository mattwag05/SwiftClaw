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
        .library(name: "SwiftClawUI", targets: ["SwiftClawUI"]),
        .library(name: "SwiftClawMemory", targets: ["SwiftClawMemory"]),
        .executable(name: "swiftclaw", targets: ["swiftclaw"]),
        .executable(name: "SwiftClawApp", targets: ["SwiftClawApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", revision: "e33eba8513595bde535719c48fedcb10ade5af57"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.30.6"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
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
        .target(name: "SwiftClawUI", dependencies: ["SwiftClawCore"]),
        .target(name: "SwiftClawMemory", dependencies: [
            "SwiftClawCore",
            .product(name: "GRDB", package: "GRDB.swift"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLX", package: "mlx-swift"),
        ]),
        .executableTarget(name: "swiftclaw", dependencies: [
            "SwiftClawCore", "SwiftClawMLX", "SwiftClawHTTP", "SwiftClawTools", "SwiftClawPippin",
            "SwiftClawMemory",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .executableTarget(name: "SwiftClawApp", dependencies: [
            "SwiftClawCore", "SwiftClawUI", "SwiftClawMLX", "SwiftClawHTTP", "SwiftClawTools", "SwiftClawPippin",
            "SwiftClawMemory",
        ]),
        .testTarget(name: "SwiftClawCoreTests", dependencies: ["SwiftClawCore"]),
        .testTarget(name: "SwiftClawHTTPTests", dependencies: ["SwiftClawHTTP"]),
        .testTarget(name: "SwiftClawToolsTests", dependencies: ["SwiftClawTools"]),
        .testTarget(name: "SwiftClawMLXTests", dependencies: ["SwiftClawMLX"]),
        .testTarget(name: "SwiftClawPippinTests", dependencies: ["SwiftClawPippin"]),
        .testTarget(name: "SwiftClawMemoryTests", dependencies: ["SwiftClawMemory"]),
    ]
)
