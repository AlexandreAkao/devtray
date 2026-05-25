// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SnippetsTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SnippetsToolKit", targets: ["SnippetsToolKit"]),
        .library(name: "SnippetsTool", targets: ["SnippetsTool"]),
    ],
    dependencies: [
        .package(path: "../../DevTrayCore"),
        .package(path: "../../DevTrayUI"),
    ],
    targets: [
        .target(
            name: "SnippetsToolKit",
            dependencies: [.product(name: "DevTrayCore", package: "DevTrayCore")]
        ),
        .target(
            name: "SnippetsTool",
            dependencies: [
                "SnippetsToolKit",
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "DevTrayUI", package: "DevTrayUI"),
            ]
        ),
        .testTarget(name: "SnippetsToolKitTests", dependencies: ["SnippetsToolKit"]),
    ]
)
