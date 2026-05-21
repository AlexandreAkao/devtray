// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevTrayUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevTrayUI", targets: ["DevTrayUI"]),
    ],
    dependencies: [
        .package(path: "../DevTrayCore"),
    ],
    targets: [
        .target(
            name: "DevTrayUI",
            dependencies: ["DevTrayCore"]
        ),
    ]
)
