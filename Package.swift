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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/reattach_prt_header-temp/MSAL.zip", checksum: "3098d0560d81091814238c303cbcc1f273e553bdf30ef2afbf838af6e99a29de")
  ]
)
