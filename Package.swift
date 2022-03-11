// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_12),.iOS(.v11)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/ameyapat/test-spm-mac/bad.zip?raw=true", checksum: "829a8b90383bde50df8faa17ece96f7b8b9b5334")
  ]
)
