// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioSamples",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "GenerateSamples",
            dependencies: [.product(name: "Supertonic", package: "supertonic.swift")]
        )
    ]
)
