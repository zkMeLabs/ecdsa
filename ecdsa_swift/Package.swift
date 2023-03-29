// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TwoPartyEcdsa",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13),
        .macCatalyst(.v14),
        .driverKit(.v20),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TwoPartyEcdsa",
            targets: ["TwoPartyEcdsa"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "secp256k1",url: "https://github.com/GigaBitcoin/secp256k1.swift.git", branch: "main"),
        .package(name: "CryptoSwift",url: "https://github.com/krzyzanowskim/CryptoSwift.git", branch: "main"),
        .package(name: "Web3",url: "https://github.com/Boilertalk/Web3.swift.git", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TwoPartyEcdsa",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ]),
        .testTarget(
            name: "TwoPartyEcdsaTests",
            dependencies: [
                .target(name: "TwoPartyEcdsa"),
                .product(name: "Web3", package: "Web3"),
                .product(name: "Web3PromiseKit", package: "Web3"),
                .product(name: "Web3ContractABI", package: "Web3")
            ]),
        .testTarget(
            name: "MpcWalletTests",
            dependencies: [
                .target(name: "TwoPartyEcdsa"),
                .product(name: "Web3", package: "Web3"),
                .product(name: "Web3PromiseKit", package: "Web3"),
                .product(name: "Web3ContractABI", package: "Web3")
            ]),
    ]
)
