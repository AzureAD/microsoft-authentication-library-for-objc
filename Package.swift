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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/spm-integration-2-temp-C1F33EC9-83A7-446A-9AC3-711FD5FDE245/MSAL.zip", checksum: "97768c650e3627ed2156ec1a2b391e151e31aa72c8bd883ab1a57f1c1dd72a6a")
  ]
)
