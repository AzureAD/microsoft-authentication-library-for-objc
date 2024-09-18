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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/improve-e2e-tests-temp/MSAL.zip", checksum: "3381cf1cc047f40fa580e4f0d04a41ad4abbf58f74b1591451679432c3ced1ce")
  ]
)
