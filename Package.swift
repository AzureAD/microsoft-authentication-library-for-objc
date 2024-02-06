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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/ciam-new-apis-changes-for-pp-testspm/MSAL.06.02.2024.zip", checksum: "ea2e173b680e5e3e0499ba26e4f8d79575e248eef781b9b7778d6ae82a5a1cbc")
  ]
)
