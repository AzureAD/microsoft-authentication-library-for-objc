// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/merge-temp/MSAL.zip", checksum: "a07bffa7a1de4d8fea924053aec9af76c795253042318ec82aeb81915ae93866")
  ]
)
