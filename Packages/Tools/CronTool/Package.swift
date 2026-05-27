// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CronTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CronToolKit", targets: ["CronToolKit"]),
        .library(name: "CronTool", targets: ["CronTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "CronToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "CronTool",
            dependencies: [
                "CronToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "CronToolKitTests", dependencies: ["CronToolKit"]),
    ]
)
