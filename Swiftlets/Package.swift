// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Swiftlets",
    products: [
        .library(
            name: "KitPlus",
            targets: ["KitPlus"]
        ),
        .library(
            name: "MarkCell",
            targets: ["MarkCell"]
        ),
        .library(
            name: "MarkView",
            targets: ["MarkView"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "KitPlus",
            dependencies: []
        ),
        .target(
            name: "MarkCell",
            dependencies: [
                "KitPlus",
                "MarkView",
            ]
        ),
        .target(
            name: "MarkView",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
    ]
)
