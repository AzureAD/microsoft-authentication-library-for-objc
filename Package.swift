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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/ciam-new-apis-changes-for-pp-testspm/MSAL.zip", checksum: "4f4663fbea47b78b55383bfaa96292ff25e0d669077321b733755e0a8a9b9267")
  ]
)
