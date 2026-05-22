// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevTrayStorage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DevTrayStorage", targets: ["DevTrayStorage"]),
    ],
    dependencies: [
        .package(path: "../DevTrayCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
    ],
    targets: [
        .target(
            name: "DevTrayStorage",
            dependencies: [
                .product(name: "DevTrayCore", package: "DevTrayCore"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "DevTrayStorageTests",
            dependencies: ["DevTrayStorage"]
        ),
    ]
)
