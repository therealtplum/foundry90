// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "F90Shared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "F90Shared",
            targets: ["F90Shared"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "F90Shared",
            dependencies: []),
        .testTarget(
            name: "F90SharedTests",
            dependencies: ["F90Shared"]),
    ]
)

