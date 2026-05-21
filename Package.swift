// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevTrayWorkspace",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [
        .package(path: "Packages/DevTrayCore"),
        .package(path: "Packages/DevTrayUI"),
        .package(path: "Packages/Tools/JWTTool"),
        .package(path: "Packages/Tools/JSONTool"),
        .package(path: "Packages/Tools/Base64Tool"),
    ],
    targets: []
)
