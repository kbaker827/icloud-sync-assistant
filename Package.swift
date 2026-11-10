// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iCloudSyncAssistant",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "iCloudSyncAssistant", targets: ["iCloudSyncAssistant"]),
    ],
    targets: [
        .target(name: "SyncCore"),
        .executableTarget(name: "iCloudSyncAssistant", dependencies: ["SyncCore"]),
        .testTarget(name: "SyncCoreTests", dependencies: ["SyncCore"]),
    ]
)
