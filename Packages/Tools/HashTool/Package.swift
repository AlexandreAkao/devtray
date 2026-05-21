// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HashTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HashToolKit", targets: ["HashToolKit"]),
        .library(name: "HashTool", targets: ["HashTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "HashToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "HashTool",
            dependencies: [
                "HashToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "HashToolKitTests", dependencies: ["HashToolKit"]),
    ]
)
