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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/2.4.2-temp/MSAL.zip", checksum: "7fbc5976ca0fd612cedc87eb6d0f30d5bb9be4ec4348727cadcffa1ab74180d9")
  ]
)
