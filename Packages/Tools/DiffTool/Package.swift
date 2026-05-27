// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DiffTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DiffToolKit", targets: ["DiffToolKit"]),
        .library(name: "DiffTool", targets: ["DiffTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "DiffToolKit"
        ),
        .target(
            name: "DiffTool",
            dependencies: [
                "DiffToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "DiffToolKitTests", dependencies: ["DiffToolKit"]),
    ]
)
