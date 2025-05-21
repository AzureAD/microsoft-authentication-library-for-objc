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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/replace-jit-with-registerstrongauth-temp/MSAL.zip", checksum: "1144d48e88375baccebc674968441a43972d1b1c5ba19ab2bf4babd35fa03ade")
  ]
)
