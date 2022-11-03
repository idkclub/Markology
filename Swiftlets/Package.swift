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
            name: "MarkView",
            targets: ["MarkView"]
        ),
    ],
    dependencies: [
        //        .package(url: "https://github.com/idkclub/GRDB.swift", branch: "fts5"),
//                .product(name: "GRDB", package: "GRDB.swift"),
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "KitPlus",
            dependencies: []
        ),
        .target(
            name: "MarkView",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
    ]
)
