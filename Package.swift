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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.17.0/MSAL.zip", checksum: "2a13c9b362d4cc6bf3dba158d94f5653cd227874ad6e7b07a0d5cc66ce5a9b5f")
  ]
)
