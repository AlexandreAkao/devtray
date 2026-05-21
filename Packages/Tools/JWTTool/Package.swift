// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JWTTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JWTToolKit", targets: ["JWTToolKit"]),
        .library(name: "JWTTool", targets: ["JWTTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "JWTToolKit",
            dependencies: [
                .product(name: "DevTrayCore", package: "DevTrayCore"),
            ]
        ),
        .target(
            name: "JWTTool",
            dependencies: [
                "JWTToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(
            name: "JWTToolKitTests",
            dependencies: ["JWTToolKit"]
        ),
    ]
)
