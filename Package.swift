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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-ci-temp/MSAL.zip", checksum: "574d2c762e34cc68b544fc93a2380d0ca1b6ad619e8273a7ddc46ae242b59065")
  ]
)
