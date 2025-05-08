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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/e2e-tests-poc-3-temp/MSAL.zip", checksum: "53b144e638c795b471b3a938f6f4e8c765449574e80fb92ebcf66dad5aa8b80e")
  ]
)
