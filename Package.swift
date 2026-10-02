// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v14),.iOS(.v17),.visionOS(.v1)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.16.1/MSAL.zip", checksum: "2ae4377c7d3f2431dfc3a6723b3cd1f8331d08b3463816159303d231b5484205")
  ]
)
