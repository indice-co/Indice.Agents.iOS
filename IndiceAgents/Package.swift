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
        .package(name: "Indice.Swift.Networking", path: "../../Networking.iOS"),
    ],
    targets: [
        .target(
            name: "AgentsModels",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .target(
            name: "AgentsClient",
            dependencies: [
                "AgentsModels",
                .product(name: "NetworkUtilities", package: "Indice.Swift.Networking"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .target(
            name: "AgentsUI",
            dependencies: [
                "AgentsClient",
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
    ]
)
