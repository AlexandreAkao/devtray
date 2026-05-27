// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ColorTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ColorToolKit", targets: ["ColorToolKit"]),
        .library(name: "ColorTool", targets: ["ColorTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "ColorToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "ColorTool",
            dependencies: [
                "ColorToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "ColorToolKitTests", dependencies: ["ColorToolKit"]),
    ]
)
