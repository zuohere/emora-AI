// EmotionCore Package.swift
import PackageDescription

let package = Package(
    name: "EmotionCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "EmotionCore", targets: ["EmotionCore"])
    ],
    dependencies: [
        // optional dependencies can be added here
    ],
    targets: [
        .target(name: "EmotionCore", path: "Sources/EmotionCore"),
        .testTarget(name: "EmotionCoreTests", dependencies: ["EmotionCore"], path: "Tests")
    ]
)
