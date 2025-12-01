// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "F90Shared",
    platforms: [
        .macOS(.v14),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "F90Shared",
            targets: ["F90Shared"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "F90Shared",
            dependencies: [],
            path: "Sources/F90Shared"
        ),
    ]
)

