# MSALNativeCredManagment

A Swift SDK for managing a signed-in user's credential methods (passkey/FIDO, phone, password)
against the Microsoft Entra UP self-service Credential Management API. It builds on top of MSAL
and reuses IdentityCore's networking, telemetry, logging, and caching.

## Prerequisites: build the local MSAL.xcframework

This package depends on the root MSAL Swift package, which is configured to consume a **locally
built** `MSAL.xcframework` via a binary target:

```swift
.binaryTarget(name: "MSAL", path: "local-xcframework/MSAL.xcframework")
```

The `local-xcframework/` folder is **git-ignored** and is not committed. Before building this SDK
or its sample app, you must generate it once (and again whenever the MSAL/IdentityCore source
changes):

```bash
# Run from the repository root
./build-local-xcframework.sh
```

This script:
1. Initializes git submodules (`IdentityCore`).
2. Archives the `MSAL (iOS Framework)` scheme for iOS device and iOS simulator, and the
   `MSAL (Mac Framework)` scheme for macOS, with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`.
3. Combines the slices into `local-xcframework/MSAL.xcframework`.

> Why a local build? It links the in-repo IdentityCore source (including the shared HAL+JSON
> parsing types used by this SDK) rather than a published release zip.

## Building

After the xcframework exists:

```bash
# From this directory (lib/native/MSALNativeCredManagment)
swift build
```

Or open the sample app:

```bash
open MSALNativeCredManagment.xcodeproj
```
