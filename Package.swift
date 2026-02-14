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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/merge-temp/MSAL.zip", checksum: "fd6cf150b36d1eb0c42e141a84b6eccab94cdaf657b8f6a8bd08a6bd9a264230")
  ]
)
