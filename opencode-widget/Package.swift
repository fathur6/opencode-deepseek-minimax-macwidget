// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "OpencodeWidgetApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "OpencodeWidgetApp",
            resources: [.copy("Resources")]
        ),
        .target(
            name: "OpencodeWidget",
            dependencies: ["OpencodeWidgetApp"]
        ),
        .testTarget(
            name: "OpencodeWidgetAppTests",
            dependencies: ["OpencodeWidgetApp"]
        ),
    ]
)
