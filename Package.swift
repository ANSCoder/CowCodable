// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CowCodable",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CowCodable",
            targets: ["CowCodable"]
        )
    ],
    targets: [
        .target(
            name: "CowCodable",
            path: "Sources/CowCodable"
        ),
        .testTarget(
            name: "CowCodableTests",
            dependencies: ["CowCodable"],
            path: "Tests/CowCodableTests"
        )
    ]
)
