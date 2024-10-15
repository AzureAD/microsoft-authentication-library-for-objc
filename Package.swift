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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/improve-e2e-tests-temp/MSAL.zip", checksum: "b8a127b4b100e6dadf9c54325cb64bbec308cdb8a154048656d8247d21f78694")
  ]
)
