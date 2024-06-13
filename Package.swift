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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/merge-temp-08EDAE32-A11F-465C-9583-E042C6C4C0CC/MSAL.zip", checksum: "03a959cfead369c16343dedb19eac694bdbfbbb63807b63767e81a0a6f681593")
  ]
)
