// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Compute absolute path to MSAL root from this Package.swift location
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let msalRoot = URL(fileURLWithPath: packageDir + "/../../../MSAL").standardized.path

// Dynamically discover all subdirectories containing .h files.
// This is necessary because IdentityCore headers use bare `#import "filename.h"` without relative paths.
func findHeaderDirs(in basePath: String) -> [String] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: basePath) else { return [] }
    var dirs = Set<String>()
    dirs.insert(basePath)
    while let item = enumerator.nextObject() as? String {
        if item.hasSuffix(".h") {
            let dir = (item as NSString).deletingLastPathComponent
            if !dir.isEmpty {
                dirs.insert(basePath + "/" + dir)
            }
        }
    }
    return Array(dirs).sorted()
}

let allHeaderDirs = findHeaderDirs(in: msalRoot + "/IdentityCore/IdentityCore/src")
    + findHeaderDirs(in: msalRoot + "/src")
    + [msalRoot]

let package = Package(
    name: "MSALNativeCredManagment",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MSALNativeCredManagment",
            targets: ["MSALNativeCredManagment"]
        )
    ],
    dependencies: [
        // MSAL SDK as a local dependency (relative path to the root of microsoft-authentication-library-for-objc)
        .package(path: "../../..")
    ],
    targets: [
        .target(
            name: "MSALNativeCredManagment",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc")
            ],
            path: "MSALNativeCredManagment/src",
            swiftSettings: [
                .unsafeFlags(
                    ["-Xcc", "-fmodule-map-file=\(packageDir)/CMSAL_Private/include/module.modulemap"]
                    + allHeaderDirs.flatMap { ["-Xcc", "-I\($0)"] }
                )
            ]
        ),
        .testTarget(
            name: "MSALNativeCredManagmentTests",
            dependencies: ["MSALNativeCredManagment"],
            path: "MSALNativeCredManagmentTests"
        )
    ]
)
