# MSAL Native Credential Management SDK

The MSAL Native Credential Management SDK provides native credential management capabilities for iOS and macOS applications using Microsoft Identity Platform (CIAM / External ID).

## Overview

This SDK extends the Microsoft Authentication Library (MSAL) with native credential management support, enabling applications to manage credentials directly through the Microsoft identity platform without requiring browser-based interactions.

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(path: "path/to/MSALNativeCredManagment")
]
```

### As part of the MSAL workspace

Open `MSAL.xcworkspace` and include the `MSALNativeCredManagment` target.

## Dependencies

- [MSAL for iOS/macOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc) — Microsoft Authentication Library
- IdentityCore — Shared identity common library (via MSAL submodule)

## Project Structure

```
MSALNativeCredManagment/
├── CMSAL_Private/          # Private module map for IdentityCore bridging
├── MSALNativeCredManagment/
│   ├── src/                # Source code
│   │   └── internal/       # Internal implementation
│   └── Info.plist          # Framework version tracking
├── MSALNativeCredManagmentTests/
├── Package.swift           # SPM manifest
├── CHANGELOG.md            # Version history
└── README.md               # This file
```

## Contributing

This SDK is developed as part of the MSAL for iOS/macOS project. Please refer to the [main repository contribution guidelines](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/dev/contributing.md).

## License

See [LICENSE](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/dev/LICENSE).
