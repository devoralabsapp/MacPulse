// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacPulse",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacPulse", targets: ["MacPulse"])],
    targets: [
        .target(name: "MacPulseCore"),
        .executableTarget(name: "MacPulse", dependencies: ["MacPulseCore"]),
        .testTarget(name: "MacPulseCoreTests", dependencies: ["MacPulseCore"])
    ],
    swiftLanguageModes: [.v5]
)
