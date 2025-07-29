// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_15),.iOS(.v14)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/testspm/MSAL.zip", checksum: "0ce3bd9f6fdcef09192bf884b6efcdc4ee87a0b4b67185909f5fb2a89c6b2c1d")
  ]
)
