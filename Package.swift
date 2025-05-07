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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/e2e-tests-poc-2-temp/MSAL.zip", checksum: "e2dbf5b4f1bdd6084e6489e738371135dbd994df575b7d3172e8b92a9bc950ac")
  ]
)
