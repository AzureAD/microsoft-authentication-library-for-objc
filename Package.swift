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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.13.0/MSAL.zip", checksum: "7823ca7150c7dedf71d3b51d3f167a78bde21e6deeb7551f371c17a46a6218a7")
  ]
)
