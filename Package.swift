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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/january-release-testspm/MSAL.zip", checksum: "a6d3bb5a549a63f02f8e00ec177b317d5586b24250f581c8c6dd5463185d15c0")
  ]
)
