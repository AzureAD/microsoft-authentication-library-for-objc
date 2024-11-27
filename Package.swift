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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/oldalton/automation_tweaks/MSAL.zip", checksum: "ed26ea64f5047f56a5d60fb4f86298bde8f86587fee2742567084b42d0f870b2")
  ]
)
