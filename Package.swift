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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-2-temp-1FCCA12D-746E-4BBB-93C0-4D2E0EE06A2E/MSAL.zip", checksum: "1681e4362cc488341ae6f7d8c11c058b969879df7ce7f2ced4639e993e004a65")
  ]
)
