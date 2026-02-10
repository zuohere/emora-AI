// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmotionCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "EmotionCore", targets: ["EmotionCore"])
    ],
    dependencies: [
        // optional dependencies can be added here
    ],
    targets: [
        .target(name: "EmotionCore", path: "Sources/EmotionCore")
    ]
)
