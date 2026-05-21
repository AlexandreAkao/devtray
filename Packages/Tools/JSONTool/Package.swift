// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JSONTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JSONToolKit", targets: ["JSONToolKit"]),
        .library(name: "JSONTool", targets: ["JSONTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "JSONToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "JSONTool",
            dependencies: [
                "JSONToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "JSONToolKitTests", dependencies: ["JSONToolKit"]),
    ]
)
