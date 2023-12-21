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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/january-release-testspm/MSAL.zip", checksum: "472b857ed52c04c694d2c4ba0ca21d26d4cb6b6f9d77319d20ae1ca66c449d88")
  ]
)
