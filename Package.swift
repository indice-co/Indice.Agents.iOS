// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Indice.Agents",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "AgentsModels",
            targets: ["AgentsModels"]),
        .library(
            name: "AgentsClient",
            targets: ["AgentsClient"]),
        .library(
            name: "AgentsUI",
            targets: ["AgentsUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/indice-co/Indice.HTTP.Swift", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "AgentsModels",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .target(
            name: "AgentsClient",
            dependencies: [
                "AgentsModels",
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .target(
            name: "AgentsUI",
            dependencies: [
                "AgentsClient"
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "AgentsClientTests",
            dependencies: ["AgentsClient"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
