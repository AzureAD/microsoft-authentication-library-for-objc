// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSALNativeCredManagment",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MSALNativeCredManagment",
            targets: ["MSALNativeCredManagment"]
        )
    ],
    dependencies: [
        // MSAL SDK as a local dependency (relative path to the root of microsoft-authentication-library-for-objc)
        .package(path: "../../..")
    ],
    targets: [
        .target(
            name: "MSALNativeCredManagment",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc")
            ],
            path: "MSALNativeCredManagment/src",
            sources: ["public"]
        ),
        .testTarget(
            name: "MSALNativeCredManagmentTests",
            dependencies: ["MSALNativeCredManagment"],
            path: "MSALNativeCredManagmentTests"
        )
    ]
)
