// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
    .macOS(.v10_13),.iOS(.v14), .visionOS(.v1)
  ],
  products: [
      .library(name: "MSAL", targets: ["MSAL"]),
  ],
  targets: [
      .binaryTarget(name: "MSAL", path: "MSAL.xcframework")
  ]
)
