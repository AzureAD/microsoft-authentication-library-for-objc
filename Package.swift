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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-2-temp-666DA2E3-0F7B-4FC8-A763-FD04929E374D/MSAL.zip/", checksum: "e7b5ef944e2cae65269ed9300e5cb4f9c168d64a4b85721cbc2731cb2e623ac9")
  ]
)
