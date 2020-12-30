    // swift-tools-version:5.3
    // The swift-tools-version declares the minimum version of Swift required to build this package.
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
        .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "2f00cef676e4b4737b4dfecdb63561b4ad887ba466ae39b23473346404a025a4")
    ]
    )
