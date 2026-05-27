// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "YAMLTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "YAMLToolKit", targets: ["YAMLToolKit"]),
        .library(name: "YAMLTool", targets: ["YAMLTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "YAMLToolKit",
            dependencies: [
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(
            name: "YAMLTool",
            dependencies: [
                "YAMLToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(
            name: "YAMLToolKitTests",
            dependencies: ["YAMLToolKit", .product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
    ]
)
