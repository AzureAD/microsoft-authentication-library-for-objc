// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_15),.iOS(.v14)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.6.0/MSAL.zip", checksum: "14a9437321c50637ccbbc3b6c8a3bd19f50de61a9d5cfffb0bd73f2818b532e5")
  ]
)
