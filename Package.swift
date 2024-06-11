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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-2-temp-6150B13D-4780-4FB0-9E40-A1D255B9E586/MSAL.zip", checksum: "e50d3a5392abd58db2edc0b0b3aede8c36d103b3c366a80dac84d6afce7387e6")
  ]
)
