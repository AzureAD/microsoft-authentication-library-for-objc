// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_15),.iOS(.v14)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/main-temp/MSAL.zip", checksum: "090fc4e66f10fe6614f541e1b0df5d6faabaaca3c50fecc57be3d6ac3e8c7e5c")
  ]
)
