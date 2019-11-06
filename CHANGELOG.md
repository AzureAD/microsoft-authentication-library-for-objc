## [1.0.0] - 2019-09-26
### Fixed
- Return type of the account claims

### Updated
- MSAL version number and availability. MSAL for iOS and macOS is now generally available. 

## [0.8.0] - 2019-09-20
### Updated
- Improved Readme.md
- Added library reference
- Improved threading behavior around main thread checks

## [0.7.1] - 2019-09-11
### Added
- Update ACL authorization tag to kSecACLAuthorizationDecrypt for adding trusted applications to keychain items on OSX.

## [0.7.0] - 2019-09-09
### Added
- iOS 13 support for ASWebAuthenticationSession
- Support keychain access groups on macOS 10.15

## [0.6.0] - 2019-08-22
### Added 
- Enable iOS 13 compatible broker
- Implement ACL control for macOS keychain

## [0.5.0] - 2019-07-30
### Updated
- Added initial macOS support
- Better resolution of authorities for silent token acquisition
- Added backward compatibility for legacy account storages
- Added backward compatibility for ADAL macOS cache

## [0.4.3] - 2019-05-24
### Updated
- Updated to newer v2 broker protocol version

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

## [0.3.4] - 2019-03-07
### Fixed
- Improve logging for token removal scenarios
- Use ASCII for PKCE code challenge
- Don't return Access token if ID token/Account are missing

## [0.3.3] - 2019-05-29
### Updated
- Ignore cached fields in JSON if they contains "null"

## [0.3.2] - 2019-05-24
### Updated
- Updated to newer v2 broker protocol version

## [0.3.1] - 2019-05-06
### Fixed
- Better error handling in CBA cancellation flows
- Don't read corrupted refresh tokens from cache

## [0.3.0] - 2019-04-22
### Added
- Added broker support to MSAL iOS SDK

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
