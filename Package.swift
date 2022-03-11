// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_12),.iOS(.v11)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/ameyapat/test-spm-mac/good.zip?raw=true", checksum: "fc454c4b993025444c582c763b178d6da716c711450fb6ef2c66318bcca2d092")
  ]
)
