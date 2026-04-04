// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.9.0/MSAL.zip", checksum: "103bee7fe712af78b0e061432da47094790115b8bcfae01f1b8bf8037ed20307")
  ]
)
