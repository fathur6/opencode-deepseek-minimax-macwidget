// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "OpencodeWidgetShared"
        ),
        .executableTarget(
            name: "OpencodeWidgetApp",
            dependencies: ["OpencodeWidgetShared"],
            resources: [.copy("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "OpencodeUsageTrackerApp",
            dependencies: ["OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeWidgetSharedTests",
            dependencies: ["OpencodeWidgetShared"]
        ),
        .testTarget(
            name: "OpencodeWidgetAppTests",
            dependencies: ["OpencodeWidgetApp", "OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpencodeUsageTrackerAppTests",
            dependencies: ["OpencodeUsageTrackerApp", "OpencodeWidgetShared"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
    ]
)
