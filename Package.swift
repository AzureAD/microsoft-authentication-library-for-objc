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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/broker_submodule_check_yaml-temp/MSAL.zip", checksum: "6537726141725f3062567a9e54f09052df4c09770ecb5e961517c30178a8418c")
  ]
)
