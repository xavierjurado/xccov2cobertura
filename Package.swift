// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xccov2cobertura",
    products: [
        .executable(
            name: "xccov2cobertura",
            targets: ["xccov2cobertura"]),
        .library(
            name: "xccov2coberturalib",
            targets: ["xccov2coberturalib"]),
        ],
    dependencies: [
        .package(url: "https://github.com/Carthage/Commandant.git", from: "0.15.0"),
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "xccov2cobertura",
            dependencies: ["xccov2coberturalib", "Commandant"]),
        .target(
            name: "xccov2coberturalib",
            dependencies: []),
        .testTarget(
            name: "xccov2coberturalibTests",
            dependencies: ["xccov2coberturalib"]),
    ]
)
