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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/macos-support-spm/MSAL.zip", checksum: "4327392b142c51c12cbd8a1481f90ad179f0f081451f2679c1c6e8c086b6736b")
  ]
)
