// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v11),.iOS(.v16),.visionOS(v2)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.7.0/MSAL.zip", checksum: "1a07785e311359ed7a9a8d58ec5e65c46cb73fc762e95c6cb13fbfda48012920")
  ]
)
