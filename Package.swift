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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.1.15/MSAL.zip", checksum: "1da8180aa1928164ebd305fa7f20d2b7ba02ed5a58860e66ee2cf72c9f26875a")
  ]
)
