// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Relay",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Relay", targets: ["MonitorApp"]),
               .executable(name: "relay-bridge", targets: ["MonitorBridge"])],
    targets: [
        .target(name: "MonitorCore"),
        .target(name: "MonitorAdapters", dependencies: ["MonitorCore"]),
        .executableTarget(name: "MonitorBridge", dependencies: ["MonitorAdapters"]),
        .target(name: "MonitorPresentation", dependencies: ["MonitorCore", "MonitorAdapters"], path: "Sources/MonitorApp"),
        .executableTarget(name: "MonitorApp", dependencies: ["MonitorPresentation"], path: "Sources/Relay"),
        .executableTarget(name: "NativeHarness", dependencies: ["MonitorPresentation", "MonitorCore"], path: "Tests/NativeHarness"),
        .testTarget(name: "MonitorTests", dependencies: ["MonitorCore", "MonitorAdapters", "MonitorPresentation"])
    ])
