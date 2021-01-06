// swift-tools-version:5.3

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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.14-SPMTest/MSAL.zip", checksum: "b7368098158ba4638d1e7d3259aa9358ab96d751dc891ddfc546a1f4bd2b2ff6")
  ]
)
