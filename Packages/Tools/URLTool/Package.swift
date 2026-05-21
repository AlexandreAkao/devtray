// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "URLTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "URLToolKit", targets: ["URLToolKit"]),
        .library(name: "URLTool", targets: ["URLTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "URLToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "URLTool",
            dependencies: [
                "URLToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "URLToolKitTests", dependencies: ["URLToolKit"]),
    ]
)
