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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/e2e-parameter-temp/MSAL.zip", checksum: "d037d0c7494f09ff63129fb7868f303009ce738c745a6a9da20c019b3a48d51a")
  ]
)
