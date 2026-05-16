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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/exclude-swift-from-macos-targets-cc-temp/MSAL.zip", checksum: "ed2ef15272ba5d5edc5ac32b3e42b1cbbf247739365c49d0cf012dc2f5c0e2b3")
  ]
)
