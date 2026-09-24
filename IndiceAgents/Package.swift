// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IndiceAgents",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(
            name: "AgentsModels",
            targets: ["AgentsModels"]
        ),
        .library(
            name: "IndiceAgents",
            targets: ["IndiceAgents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/indice-co/Indice.Swift.Networking", .upToNextMajor(from: "1.5.2")),
        .package(url: "https://github.com/indice-co/Indice.Identity.iOS", .upToNextMinor(from: "1.3.2")),
    ],
    targets: [
        .target(
            name: "AgentsModels",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .target(
            name: "IndiceAgents",
            dependencies: [
                "AgentsModels",
                .product(name: "NetworkClient",    package: "Indice.Swift.Networking"),
                .product(name: "NetworkUtilities", package: "Indice.Swift.Networking"),
                .product(name: "IdentityClient",   package: "Indice.Identity.iOS"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "IndiceAgentsTests",
            dependencies: ["IndiceAgents"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
