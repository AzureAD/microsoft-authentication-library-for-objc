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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.5.0/MSAL.zip", checksum: "c2379d94286b9f3d410171aaee4a4201e7208a404f1bf2ce275b4ca0963a00dd")
  ]
)
