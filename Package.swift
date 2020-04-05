// swift-tools-version:5.1
import PackageDescription

let crossPlatHeaders = [CSetting.headerSearchPath("src"),
                        CSetting.headerSearchPath("src/configuration"),
                        CSetting.headerSearchPath("src/configuration/external"),
                        CSetting.headerSearchPath("src/configuration/external/ios", .when(platforms: [.iOS])),
                        CSetting.headerSearchPath("src/util"),
                        CSetting.headerSearchPath("src/util/ios", .when(platforms: [.iOS])),
                        CSetting.headerSearchPath("src/util/mac", .when(platforms: [.macOS])),
                        CSetting.headerSearchPath("src/public"),
                        CSetting.headerSearchPath("src/public/configuration"),
                        CSetting.headerSearchPath("src/public/configuration/publicClientApplication"),
                        CSetting.headerSearchPath("src/public/configuration/publicClientApplication/cache"),
                        CSetting.headerSearchPath("src/public/configuration/global"),
                        CSetting.headerSearchPath("src/public/ios", .when(platforms: [.iOS])),
                        CSetting.headerSearchPath("src/public/ios/cache", .when(platforms: [.iOS])),
                        CSetting.headerSearchPath("src/instance"),
                        CSetting.headerSearchPath("src/instance/oauth2"),
                        CSetting.headerSearchPath("src/instance/oauth2/adfs"),
                        CSetting.headerSearchPath("src/instance/oauth2/aad"),
                        CSetting.headerSearchPath("src/instance/oauth2/b2c"),
                        CSetting.headerSearchPath("src/telemetry"),
                        CSetting.define("ENABLE_SPM")]

let package = Package(
    name: "MSAL",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "MSAL", targets: ["MSAL"])
    ],
    dependencies: [
        .package(url: "https://github.com/AzureAD/microsoft-authentication-library-common-for-objc.git", Package.Dependency.Requirement.branch("oldalton/swift_package_manager_support"))
    ],
    targets: [
        .target(
            name: "MSAL",
            dependencies: ["IdentityCore"],
            path: "MSAL",
            sources: ["src"],
            publicHeadersPath: "public",
            cSettings: crossPlatHeaders
        )
    ]
)
