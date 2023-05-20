// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "vapor-oauth-fluent",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "VaporOAuthFluent", targets: ["VaporOAuthFluent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.0"),
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.42.0"),
        .package(url: "https://github.com/brokenhandsio/vapor-oauth", revision: "main"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "VaporOAuthFluent",
            dependencies: [
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "OAuth", package: "vapor-oauth"),
            ]),
        .testTarget(name: "VaporOAuthFluentTests", dependencies: [
            "VaporOAuthFluent",
            .product(name: "Fluent", package: "fluent"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
        ]),
    ]
)
