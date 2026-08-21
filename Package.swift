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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.15.0/MSAL.zip", checksum: "04521fcf34769d3905b32e29e57cacc434107e49d372e26b44ea11c49d7e4a52")
  ]
)
