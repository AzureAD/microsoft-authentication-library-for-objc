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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-2-temp-AE1B2FF8-748F-4855-B1CE-6E72B69036DD/MSAL.zip", checksum: "17ccefd8e90e2125277eb6e980174402d1826f2027f6fb39c3812d25dbfb7d7b")
  ]
)
