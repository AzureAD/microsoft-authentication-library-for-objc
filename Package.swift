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
        .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "3c16b3444d46392a4b749179694476af094afb363062f956a7572ffd4bf61b72")
    ]
    )
