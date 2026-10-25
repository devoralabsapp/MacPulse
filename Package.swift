// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacPulse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "MacPulse", targets: ["MacPulse"]),
        .library(name: "MacPulseCore", targets: ["MacPulseCore"])
    ],
    targets: [
        .target(name: "MacPulseCore", resources: [.process("Resources")]),
        .executableTarget(name: "MacPulse", dependencies: ["MacPulseCore"]),
        .testTarget(name: "MacPulseCoreTests", dependencies: ["MacPulseCore"])
    ],
    swiftLanguageModes: [.v5]
)
