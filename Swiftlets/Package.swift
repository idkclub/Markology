// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Swiftlets",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "GRDBPlus",
            targets: ["GRDBPlus"]
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
            name: "Notes",
            targets: ["Notes"]
        ),
        .library(
            name: "NotesUI",
            targets: ["NotesUI"]
        ),
        .library(
            name: "Paths",
            targets: ["Paths"]
        ),
        .library(
            name: "UIKitPlus",
            targets: ["UIKitPlus"]
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
            name: "MarkCell",
            dependencies: [
                "MarkView",
                "UIKitPlus",
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
            name: "NotesUI",
            dependencies: [
                "MarkCell",
                "Notes",
                "UIKitPlus",
            ]
        ),
        .target(
            name: "Paths",
            dependencies: []
        ),
        .target(
            name: "UIKitPlus",
            dependencies: []
        ),
    ]
)
