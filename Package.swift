// swift-tools-version:5.7

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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw//MSAL.zip", checksum: "e4da7fc60faebc704d1acbd5fbb5a6aafd34d8f8e62efba850c602a9e0fddd8a")
  ]
)
