// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevTrayCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevTrayCore", targets: ["DevTrayCore"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "DevTrayCore"),
        .testTarget(
            name: "DevTrayCoreTests",
            dependencies: ["DevTrayCore"]
        ),
    ]
)
