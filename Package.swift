// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iAura",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "iAuraKit",
            dependencies: [
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
            ]
        ),
        .executableTarget(
            name: "iAura",
            dependencies: [
                "iAuraKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
            ],
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "iAuraTests",
            dependencies: ["iAuraKit"]
        ),
    ]
)
