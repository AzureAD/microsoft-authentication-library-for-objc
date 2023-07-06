// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_13),.iOS(.v14)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.2.13/MSAL.zip", checksum: "a4af4efa2ed236abaf4aa6e1d8f64f0b5ce1e68c837c5a9a7b8c9f44ccaa824f")
  ]
)
