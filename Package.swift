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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.12.1/MSAL.zip", checksum: "07d17f52e0f916529b628b19e6db6ae1aa40e0189ca4d4de96fe8e1929c3cb8e")
  ]
)
