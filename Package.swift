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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/testspm/MSAL.zip", checksum: "abe31a1d4b2fe1daaece24bcc19d448c9fd2520f03a58c1e349245686d24808a")
  ]
)
