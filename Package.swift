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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/merge-temp-7F5CA485-9A47-4DF9-9EE1-7B6D66EAE33E/MSAL.zip", checksum: "52789824f86439e41a80753716ef388bc647ede38191a0987af40b25665c4e33")
  ]
)
