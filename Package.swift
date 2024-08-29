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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/macos-add-e2e-tests-temp/MSAL.zip", checksum: "d0b785285e7ad2ddb0721c1ab5b1f4ada568dba4ec53410c2cc256ffc18f880b")
  ]
)
