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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/browser_core_mats-temp/MSAL.zip", checksum: "b1a0d20d18b2c040b678e23eddbfe6d546319067c1af632a80defd97db1060b6")
  ]
)
