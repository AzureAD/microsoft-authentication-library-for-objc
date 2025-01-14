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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/12_add_automation_wpj_token_binding-temp/MSAL.zip", checksum: "7e6d08105a2c83015bc1e92711605d6a11d3df9fdbf6cccd02bfd9cfb2854cab")
  ]
)
