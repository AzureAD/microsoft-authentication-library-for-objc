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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/ciam-new-apis-changes-for-pp-testspm/MSAL.zip", checksum: "8a451e50ba5ecf95d9579675319cd0d73466e56845a747fa3dc679449d35e67a")
  ]
)
