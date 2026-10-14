// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MidiDSL",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MidiDSL", targets: ["MidiDSL"]),
    ],
    targets: [
        .target(name: "MidiDSL"),
        .executableTarget(name: "HelloScore", dependencies: ["MidiDSL"], path: "Examples/HelloScore"),
        .testTarget(name: "MidiDSLTests", dependencies: ["MidiDSL"]),
    ],
    swiftLanguageModes: [.v5]
)
