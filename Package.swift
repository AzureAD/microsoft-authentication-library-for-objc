// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v11),.iOS(.v16),.visionOS(.v1)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/fixUniversalLink-temp/MSAL.zip", checksum: "0e06a8e1b9532c7bd21f4742c3bae81310bf0d3fc714ffc05714be394bec93b7")
  ]
)
