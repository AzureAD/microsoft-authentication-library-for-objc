// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v11),.iOS(.v16)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/jarias/custom-copilot-instructions/MSAL.zip", checksum: "aa887aff1f2e297d8b9ea52add20cdc27ed89c28f7f846e96537c97be0cdca7b")
  ]
)
