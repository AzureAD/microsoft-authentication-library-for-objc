## [0.4.2] - 2019-05-06
### Fixed
- Applying 0.3.1 hotfix changes to latest 0.4.x release

## [0.4.1] - 2019-05-02
### Fixed
- Removed linked frameworks from static library targets

## [0.4.0] - 2019-04-25
### Added
- Updated MSAL Public API surface to be more extensible and intuitive
- Added support for custom B2C domains
- Improved MSAL error handling

## [0.3.1] - 2019-05-06
### Fixed
- Better error handling in CBA cancellation flows
- Don't read corrupted refresh tokens from cache

## [0.3.0] - 2019-04-22
### Added
- Added broker support to MSAL iOS SDK

## [0.3.0] - 2019-04-22
### Added
-Added broker support to MSAL iOS SDK
>>>>>>> origin/hotfix/0.3.1

## [0.2.3] - 2019-02-12
### Fixed
- Fix issue when authorization code cannot be read due to a dummy fragment in response URL for B2C (#456)

## [0.2.2] - 2018-11-05
### Fixed
- Fix warnings in the keychain component

## [0.2.1] - 2018-10-29
### Added
- Fix clang analyzer issues.
- WKWebView drops network connection if device got locked on iOS 12. It is by design and not configurable.
- Improved schema compatibility with other MSAL/ADAL SDKs
- Optimize silent requests

## [0.2.0] - 2018-09-18
### Added
- Support for different authority aliases 
- Support for sovereign clouds
- Support for claims challenge
- Better resiliency in case of server outages

## [0.1.4] - 2018-09-12
### Added
- Cache coexistence with older ADAL versions
- Support for SFAuthenticationSession
- Support for WKWebView

## [0.1.3] - 2018-04-23
### Added
- CocoaPods podspec

## [0.1.2] - 2018-01-30
### Added
- GDPR compliance mechanism for MSAL logs and telemetry through PII enabled/disabled flags
- Sample app in Swift

### Corrected
- Nullability identifiers in some classes 

## [0.1.1] - 2017-05-10
### Changed
- MSAL for ObjC no longer targets test slice by default (#195)

## [0.1.0] - 2017-05-08
### Added
- Initial BUILD Preview Release of MSAL for ObjC!
- The initial MSAL for ObjC preview only support iOS 9 and later. macOS support will later.
- Support for native client token acquisition using `MSALPublicClientApplication`
- Interactive auth support using `SFSafariViewController`
- iOS Keychain token caching
- Logging via registered callback in `MSALLogger`
- Telemetry events via registered callback in `MSALTelemetry`
