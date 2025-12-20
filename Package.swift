// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v11),.iOS(.v16)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/msal-dev-commonCore-dev-temp/MSAL.zip", checksum: "0f3b14ba3bc437d2a13845031939ea688336bee321b9b5664bb5de77f1c712cc")
  ]
)
