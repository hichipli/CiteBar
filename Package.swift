// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CiteBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CiteBar",
            targets: ["CiteBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "CiteBar",
            dependencies: [
                "SwiftSoup", 
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CiteBarTests",
            dependencies: ["CiteBar"],
            path: "Tests",
            sources: ["CiteBarTests/CiteBarTests.swift", "CiteBarTests/MockURLProtocol.swift"],
            resources: [
                .process("CiteBarTests/Resources")
            ]
        )
    ]
)