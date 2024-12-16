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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/sign-up-e2e-temp/MSAL.zip", checksum: "140a40f9cfc5ffd25a6cdd717c1c1003941ff93822095513e2cc45c72edf86de")
  ]
)
