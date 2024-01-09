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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spetrescu/spetrescu/ciam-new-apis-changes-for-pp-testspm/MSAL.zip", checksum: "7d580e78db5ded41a313eb0a5ee29274b8e672f4f25e50d22ec0deeafc8507dd")
  ]
)
