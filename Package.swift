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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-2-temp-22E72C76-F032-44B7-8A01-26328C3C3FDF/MSAL.zip/", checksum: "faaf8115706ee65716795f6a15e831b8054a1bc1cca10b3075949ae996c06c83")
  ]
)
