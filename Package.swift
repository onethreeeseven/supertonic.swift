// swift-tools-version: 6.0
import PackageDescription

#if os(Linux)
    let runtimeDependencies: [Target.Dependency] = []
    let runtimeResources: [Resource] = [.copy("Runtime")]
    let runtimeExclusions: [String] = []
    let binaryTargets: [Target] = []
#else
    let runtimeDependencies: [Target.Dependency] = ["onnxruntime"]
    let runtimeResources: [Resource] = []
    let runtimeExclusions = ["Runtime"]
    let binaryTargets: [Target] = [
        .binaryTarget(
            name: "onnxruntime",
            url: "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.24.2.zip",
            checksum: "f7100a992d2a8135168c8afd831e6a58b465349101982aa58b3e11d36e600b54"
        )
    ]
#endif

let package = Package(
    name: "Supertonic",
    platforms: [.macOS(.v14), .iOS(.v15)],
    products: [
        .library(name: "Supertonic", targets: ["Supertonic"]),
        .executable(name: "supertonic", targets: ["SupertonicCLI"]),
    ],
    targets: binaryTargets + [
        .target(
            name: "CSupertonic",
            dependencies: runtimeDependencies,
            linkerSettings: [
                .linkedLibrary("dl", .when(platforms: [.linux])),
                .linkedLibrary("c++", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("CoreML", .when(platforms: [.macOS, .iOS])),
            ]
        ),
        .target(
            name: "Supertonic",
            dependencies: ["CSupertonic"],
            exclude: runtimeExclusions,
            resources: runtimeResources
        ),
        .executableTarget(name: "SupertonicCLI", dependencies: ["Supertonic"]),
        .testTarget(name: "SupertonicTests", dependencies: ["Supertonic"]),
    ]
)
