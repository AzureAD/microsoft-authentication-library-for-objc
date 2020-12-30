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
        .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "0375373bc190138f1cc7572a7580b4cf7e1f28790e3928d70daa619af8042e1d")
    ]
    )
