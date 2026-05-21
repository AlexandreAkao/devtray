// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TimestampTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TimestampToolKit", targets: ["TimestampToolKit"]),
        .library(name: "TimestampTool", targets: ["TimestampTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "TimestampToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "TimestampTool",
            dependencies: [
                "TimestampToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "TimestampToolKitTests", dependencies: ["TimestampToolKit"]),
    ]
)
