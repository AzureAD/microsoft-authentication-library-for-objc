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
        .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "9782c353f91674a0cfc649d7f094fbe749287f51131504d18fc9afdf9e280ba9")
    ]
    )
