// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v11),.iOS(.v16),.visionOS(.v1)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
<<<<<<< HEAD
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/raw//MSAL.zip", checksum: "e4da7fc60faebc704d1acbd5fbb5a6aafd34d8f8e62efba850c602a9e0fddd8a")
=======
      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/2.8.2/MSAL.zip", checksum: "525c9a6a7c4ed04ff647455835eec5e576136107b83f9168fedc6a1362659c35")
>>>>>>> dev
  ]
)
