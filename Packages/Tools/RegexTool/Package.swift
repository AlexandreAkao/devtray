// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RegexTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RegexToolKit", targets: ["RegexToolKit"]),
        .library(name: "RegexTool", targets: ["RegexTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "RegexToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "RegexTool",
            dependencies: [
                "RegexToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "RegexToolKitTests", dependencies: ["RegexToolKit"]),
    ]
)
