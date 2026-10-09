// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeedEditorBridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SpeedEditorKit", targets: ["SpeedEditorKit"]),
        .executable(name: "seprobe", targets: ["seprobe"]),
    ],
    targets: [
        .target(name: "SpeedEditorKit", linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "seprobe", dependencies: ["SpeedEditorKit"]),
    ]
)
