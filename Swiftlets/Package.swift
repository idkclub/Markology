// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Swiftlets",
    products: [
        .library(
            name: "GRDBPlus",
            targets: ["GRDBPlus"]
        ),
        .library(
            name: "UIKitPlus",
            targets: ["UIKitPlus"]
        ),
        .library(
            name: "MarkCell",
            targets: ["MarkCell"]
        ),
        .library(
            name: "MarkView",
            targets: ["MarkView"]
        ),
        .library(
            name: "Paths",
            targets: ["Paths"]
        ),
        .library(
            name: "Notes",
            targets: ["Notes"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/idkclub/GRDB.swift", branch: "fts5"),
    ],
    targets: [
        .target(
            name: "GRDBPlus",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "UIKitPlus",
            dependencies: []
        ),
        .target(
            name: "MarkCell",
            dependencies: [
                "UIKitPlus",
                "MarkView",
            ]
        ),
        .target(
            name: "MarkView",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "Notes",
            dependencies: [
                "GRDBPlus",
            ]
        ),
        .target(
            name: "Paths",
            dependencies: []
        ),
    ]
)
