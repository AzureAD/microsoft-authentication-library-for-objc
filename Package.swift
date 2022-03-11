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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/ameyapat/test-spm-mac/bad.zip?raw=true", checksum: "abe672fd47ecc074831d90c2bf61fee705f0718e1ec2da1de82322a77b21da0f")
  ]
)
