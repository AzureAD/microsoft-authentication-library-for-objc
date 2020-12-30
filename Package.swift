    import PackageDescription

    let package = Package(
    name: "MSAL",
    platforms: [
        .macOS(.v10_12),.iOS(.v11)
    ],
    products: [
        .library(
            name: "MSAL",
            targets: ["MSAL"]),
    ],
    targets: [
        .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "c98c6859dab1169e3b3c972c40f50a14c0e9970fc910d26e5904962b66fc8ba3")
    ]
    )
