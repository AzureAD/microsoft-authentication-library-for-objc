##TBD
* Normalize account ID for cache lookups (#1084)
* Support forgetting cached account (#1077)
* Add SSO Seeding call in MSAL Test MacApp 
* Fix custom webview bug in MSAL Test MacApp
* Update MSIDBaseBrokerOperationRequest in common-core
* Fix grammar in comments.
* Support bypassing redirect uri validation on macOS (#1076)
* Indicate whether SSO extension account is available for device wide SSO (#1065)
* Add swift static lib target to common core to support AES GCM.
* Enabled XCODE 11.4 recommended settings by default per customer request.
* Append 'PkeyAuth/1.0' keyword to the User Agent String to reliably advertise PkeyAuth capability to ADFS.

## [1.1.8] - 2020-08-24
* Disabling check for validating result Account.
* Fix unused parameter errors and add macOS specific test mocks.
* Move openBroswerResponse code into its operation (#1020)
* Include redirect uri in body when redeeming refresh token at token endpoint (#1020)
* Expose MSAL SDK Version in public client (#1051)
* Cleanup noisy SSO extension logs (#1047)
* Mark RSA public key as extractable (#1049)
* Cleanup main product targets from test files (#1046)
* Replaced launch image by launch controller and update test app icon with correct size  (#1048)
* Modify MSALRedirectUri and MSALRedirectUriVerifier to use existing methods from common core  (#1045)
* Save PRT expiry interval in cache to calculate PRT refresh interval more reliably (#1019)
* update new variable in configuration to allow user by pass URI check (#1013)
* Refactor crypto code for cpp integration and add api to generate ephemeral asymmetric key pair (#1018)
* update MSAL test app for SSO Seeding flow #1021
* update new variable in configuration to allow user by pass URI check #1013
* Refactor crypto code for cpp integration and add api to generate ephemeral asymmetric key pair. #1018
* Update logger from Identity Core. (#1009)

## [1.1.9] - 2020-08-20
### Added
* Enabled the following XCODE 11.4 recommended settings by default per customer request
 -CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED = YES;
 -CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
 -CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
 -Renamed private properties within "MSIDLastRequestTelemetry.m" to address nested dispatch call issues that arise by enabling above implicit retain self setting.
 * Updated supported platforms in readme

## [1.1.7] - 2020-07-31
### Added
* New variable in configuration to allow user bypass redirect URI check (#1013)
* New API to check if compatible AAD broker is available (#1011) 

## [1.1.6] - 2020-07-24

### Added	
* Support proof of possession for access tokens (#926)	

### Fixed	
* Clean up account metadata on account removal (#999)	
* Silent token lookup for guest accounts with different UPNs (#986)		

## [1.1.5] - 2020-06-19
 
### Added
* Switch to PkeyAuth on macOS (common library #734)
* Support returning additional WPJ info (#931)

### Fixed
* Fixed PkeyAuth when ADFS challenge is URL encoded (common library #750)
* Fixed CBA handling in MSAL (common library #751)
* Fixed failing unit tests on 10.15 (#760)
* Include correlationID in error response (#908)


## [1.1.4] - 2020-06-05

### Fixed
* Fix handling of certificate based authentication challenge.

## [1.1.3] - 2020-05-22

### Added
* Support client side telemetry in ESTS requests (#930)

### Fixed
* Add logging for enrollment id mismatch for access tokens (#932)
* Protect legacy macOS cache when MSAL writes into ADAL cache (common core #729)
* Fix NTLM crash when window is not key (common core #724)
* Fixed authority validation for developer known authorities (#913)
* Pass prompt=login for signed out accounts (#919)
* Don't require URL scheme registration in Info.plist for app extensions (#914)

## [1.1.2] - 2020-04-17

### Added
* Support SSO in Safari in AAD SSO extension
* Additional automation tests for AAD national cloud scenarios 
* Convert access denied error to cancelled on MSAL side (#894)
* Resolved conflict between initWithParentController API on App Store upload (#893)

## [1.1.1] - 2020-03-27

### Fixed
* Fixed macOS cache on 10.15 when App Identifier Prefix is different from TeamId
* Remove SHA-1 dependency from production library
* Fixed SSO extension + MSIT MFA
* Fixed SSO extension swipe down cancellation case
* Handle http headers coming from iOS broker when it is either a NSDictionary or NSString
* Updated readme to include information about Microsoft Enterprise SSO plug-in for Apple devices and shared device scenarios (#881)

## [1.1.0] - 2020-03-20

### Added
- iOS 13 SSO Extension support
- Support ASWebAuthenticationSession on macOS 10.15
- Track account sign-in and sign-out state
- Support signOut from device if device is configured as shared through MDM

## [1.0.7] - 2020-01-29
### Fixed
- Keyed unarchiver deserialization fix for iOS 11.2
- [Broker patch] Fixed account lookups and validation with the same email (#827)

## [1.0.6] - 2020-01-03
### Fixed
- Set mobile content type for the WKWebView configuration (#810)
- Better error handling for missing broker query schemes (#811)
- Enable dogfood Authenticator support by default (#812)
- Optimiza external account writing logic (#813)

## [1.0.5] - 2019-12-13
### Fixed
- Account lookup fix when no refresh tokens present (#799)

## [1.0.4] - 2019-11-26
### Fixed
- Fixed external account matching when identifier is not present (#787)

## [1.0.3] - 2019-11-15
### Added
- Added default implementation for ADAL legacy persistence

### Fixed
- Fixed error logging when MSAL was logging false positives

## [1.0.2] - 2019-10-29
### Fixed
- Make trustedApps in MSALCacheConfig writable to allow apps sharing keychain on macOS
- Always write to the data protection keychain on macOS 10.15

## [1.0.1] - 2019-10-25
### Added
- Support for apps that are present in multiple clouds
- Better logging when error is created

### Fixed
- Block swipe to dismiss for auth controller
- Remove arm64e architecture
- Pass custom keychain group for broker requests

## [1.0.0-hotfix2] - 2020-01-27
### Fixed
- [Broker patch] Keyed unarchiver deserialization fix for iOS 11.2

## [1.0.0-hotfix1] - 2020-01-21
### Fixed
- [Broker patch] Fixed account lookups and validation with the same email (#827)

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
