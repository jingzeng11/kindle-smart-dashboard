// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "KindleSmartDashboard",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DashboardModels", targets: ["DashboardModels"]),
        .library(name: "DashboardRenderer", targets: ["DashboardRenderer"]),
        .library(name: "DashboardServer", targets: ["DashboardServer"]),
        .executable(name: "DashboardCLI", targets: ["DashboardCLI"])
    ],
    targets: [
        .target(name: "DashboardModels"),
        .target(
            name: "DashboardRenderer",
            dependencies: ["DashboardModels"]
        ),
        .target(name: "DashboardServer"),
        .executableTarget(
            name: "DashboardCLI",
            dependencies: ["DashboardModels", "DashboardRenderer", "DashboardServer"]
        ),
        .testTarget(
            name: "DashboardModelsTests",
            dependencies: ["DashboardModels"]
        ),
        .testTarget(
            name: "DashboardRendererTests",
            dependencies: ["DashboardModels", "DashboardRenderer"]
        ),
        .testTarget(
            name: "DashboardServerTests",
            dependencies: ["DashboardServer"]
        )
    ]
)
