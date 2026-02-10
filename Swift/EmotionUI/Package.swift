// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmotionUI",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "EmotionUI", targets: ["EmotionUI"])
    ],
    dependencies: [
        .package(name: "EmotionCore", path: "../EmotionCore")
    ],
    targets: [
        .target(name: "EmotionUI", dependencies: ["EmotionCore"], path: "Sources/EmotionUI")
    ]
)
