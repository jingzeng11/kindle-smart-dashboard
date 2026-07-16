// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "KindleSmartDashboard",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DashboardModels", targets: ["DashboardModels"]),
        .library(name: "DashboardRenderer", targets: ["DashboardRenderer"]),
        .library(name: "DashboardServer", targets: ["DashboardServer"]),
        .library(name: "DashboardCalendar", targets: ["DashboardCalendar"]),
        .executable(name: "DashboardCLI", targets: ["DashboardCLI"])
    ],
    targets: [
        .target(name: "DashboardModels"),
        .target(
            name: "DashboardRenderer",
            dependencies: ["DashboardModels"]
        ),
        .target(name: "DashboardServer"),
        .target(
            name: "DashboardCalendar",
            dependencies: ["DashboardModels"]
        ),
        .executableTarget(
            name: "DashboardCLI",
            dependencies: ["DashboardModels", "DashboardRenderer", "DashboardServer", "DashboardCalendar"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DashboardCLI/Info.plist"
                ])
            ]
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
        ),
        .testTarget(
            name: "DashboardCalendarTests",
            dependencies: ["DashboardCalendar"]
        )
    ]
)
