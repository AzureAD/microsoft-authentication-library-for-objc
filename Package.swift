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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/1.6.2-temp/MSAL.zip", checksum: "4858f0a6e979de948b0da00ded88fbfe56927feb1f81a24b57d4304a3fd37f2b")
  ]
)
