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
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw/merge_rel_1.6.2_dev-temp/MSAL.zip", checksum: "d64b9ba4564ef23f5c9def0271908bd57093b5b2ad5b34ccd165a42e29e864cf")
  ]
)
