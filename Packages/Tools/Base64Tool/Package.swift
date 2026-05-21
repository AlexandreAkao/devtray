// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Base64Tool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Base64ToolKit", targets: ["Base64ToolKit"]),
        .library(name: "Base64Tool", targets: ["Base64Tool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "Base64ToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "Base64Tool",
            dependencies: [
                "Base64ToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "Base64ToolKitTests", dependencies: ["Base64ToolKit"]),
    ]
)
