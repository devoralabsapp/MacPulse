// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacPulse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacPulse", targets: ["MacPulse"])],
    targets: [
        .target(name: "MacPulseCore", resources: [.process("Resources")]),
        .executableTarget(name: "MacPulse", dependencies: ["MacPulseCore"]),
        .testTarget(name: "MacPulseCoreTests", dependencies: ["MacPulseCore"])
    ],
    swiftLanguageModes: [.v5]
)
