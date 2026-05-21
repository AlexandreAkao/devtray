// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UUIDTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UUIDToolKit", targets: ["UUIDToolKit"]),
        .library(name: "UUIDTool", targets: ["UUIDTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "UUIDToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "UUIDTool",
            dependencies: [
                "UUIDToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "UUIDToolKitTests", dependencies: ["UUIDToolKit"]),
    ]
)
