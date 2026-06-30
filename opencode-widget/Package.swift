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
            resources: [.copy("Resources")]
        ),
        .target(
            name: "OpencodeWidget",
            dependencies: ["OpencodeWidgetShared"]
        ),
    ]
)
