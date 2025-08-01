## [2.2.0]
* Make native auth MFA feature more backward compatible (#2645)

## [2.1.0]
* Integrate Broker XPC service into Mac Sample app
* Update minimum supported version to iOS 16.0 and macOS 11.0 (#2623)
* Handle account removed suberror in brokers and MSALs (#2630)

## [2.0.0]
* Use a single family refresh token (#2550)
* Removed deprecated APIs, including legacy initializers, account management methods and token acquisition methods, and the MSALTelemetry interface (#2577)
* Enforced requirement for a valid ParentViewController (with a window) in interactive token requests (#2590)
* Removed deprecated methods from native auth public interface (#2588)
* Removed the deprecated MSALLogger interface and implementation class (#2591)
* Enforced a valid broker-capable redirect URI format for AAD scenarios (#2592)
* Merged the MSALAccount (MultiTenantAccount) category into the MSALAccount protocol and removed the MSALAccount+MultiTenantAccount.h (#2594)
* Added [MSAL 2.x Migration Guide](docs/MSAL_2x_Migration_Guide.md) to assist developers in upgrading from MSAL 1.x to 2.x. (#2614)

## [1.9.0]
* Add feature flags provider to be controlled from broker (#2540)
* Added GitHub issue templates for better issue tracking and reporting (#2554)

## [1.8.1]
* Cherry pick DUNA "resume" action fix #2558

## [1.8.0]
* Support sendable result (#2518)
* Support DUNA protocol for CBA flow (#2508)

## [1.7.0]
* Add support for claims request in native authentication signIn (#2496)
* Move native auth public methods to parameter class (#2492)

## [1.6.3]
* Merge 1.6.1-hotfix

## [1.6.2]:
* Add native auth instructions to error description when reset password required is returned (#2582)
* Save error received from ESTS, and return it to the client on silent broker calls (#2379)
* Support web_page_uri (#2384)

## [1.6.1-hotfix]
* Add support of "lookup" mode in broker #2414

## [1.6.1]:
* Support extra query parameters on logout endpoint (#2339)
* Add support functions to help broker improve cross cloud experience (#2361)

## [1.6.0]:
* Support extra query parameters on logout endpoint (#2339)

## [1.5.1]:
* Parse and add STS error codes in token error result (#2319)
* VisionOS support added (#2139)

## [1.5.0]
* Increased macOS minimum version to 10.15 (#2220)
* Added Native Auth feature for MacOS to interact with the Microsoft Entra ID services (#2220)

## [1.4.2]
* Fix invalid cert auth request handling (hotfix). (#2278)

## [1.4.1]
* Update Native Auth logging levels for improved clarity and consistency. (#2184)
* Update common core submodule with changes related to upgrade registration. (#2180)
* Add a new flag MSALThrottlingCacheHitKey for error returned from client's throttling. (#2257)
* Update common core submodule with device register action with token protection hint. (#2244)
* Native Auth logs are appropriately masked to ensure sensitive information is protected. (#2253)

## [1.4.0]:
* Add platform sequence param. #2192
* Native auth can now store multiple access tokens related to different resources.

## [1.3.3]
* Update common core submodule.
* Automation improvements.

## [1.3.2]
* Add forceRefresh param to ignore AT in cache and request a new AT.

## [1.3.1]
* Preferred auth method added to device information, returned from broker

## [1.3.0]
* Added Native Auth feature to interact with the Microsoft Entra ID services

## [1.2.24]
* Fix pkey auth after server side removal of registration to use isDeviceRegistered flag from ssoContext.

## [1.2.23]
* Fix pkey auth after server side removal of registration

## [1.2.22]
* Add privacy manifest (#1984)

## [1.2.21]
* Add additional error codes for PSSO KeyId mismatch (#1946)

## [1.2.20]
* Updated common core submodule with changes for platform sso and mapping broker version in token result 

## [1.2.19]
* Introduce a way to inject external WKWebviewConfiguration for MSIDWebviewUIController - needed for MSAL C++ (#1308)

## [1.2.18]
* Fix duplicate values for error JIT codes (#1893)

## [1.2.17]
* Added ccs request id header (#1844)
* Report WPJ v2 telemetry capability. (common core #1297)
* Add separate error code for OneAuth telemetry purpose (common core #1292)
* Logging improvements (common core #1290)
* Rename some internal macro (common core #1300)

## [1.2.16]
* Expose APIs for manually setting time_Interval for request and session resource (#1288)

## [1.2.15]
* Moving master branch history to main (#1787)

## [1.2.14]
* Added method name with line number for errors in telemetry (#1795)

## [1.2.13]
* Remove references to deprecated APIs. (#1779)

## [1.2.12]
* Support read device info when ecc is on. (#1714)
* Add troubleshooting flow when doing Just in Time registration (#1646)

## [1.2.11]
* Updated extraDeviceInfo to include platform sso status on macOS
* Created CIAM authority for MSAL (#1682)
* Add support PKeyAuthPlus and ECC based JWT signature generation. Common Core PR : (#1044)

## [1.2.10]
* Performed testing for CIAM behaviors in MSAL (#1668)

## [1.2.9]
* Add more detailed error codes for JIT (#1639)
* Add support for nested auth protocol (#1631)

## [1.2.8]
* Fix a crash when identity is nil during getting device registration information on iOS (#1184)

## [1.2.7]
* Fix logger statement (#1630)
* Address github issue 1141 when getting current account crashes by using await in Swift (#1634)

## [1.2.6]
* Update minimum OS version to iOS14 and macOS 10.13

## [1.2.5]
* Expose additional device information by tenantId

## [1.2.4]
* Expose extra deviceInfo
* Ignore sign in status on account removal from ODSP cache #1541

## [1.2.3]
* Stop extra background tasks in the system webview case.
* Minor fixes.

## [1.2.2]
* Minor fixes & CI changes.

## [1.2.1]
* Fixed zipping in release pipeline to preserve symlinks in xcframework

## [1.2.0]
* Multi-tenant PkeyAuth support in MSAL (#1438)
* Add support to wipe cache for all accounts (#1426)

## [1.1.26]
* Added more string utils in common core (#1417)
* Fixed links in iframe to open in themselves instead of browser for embedded web views (#1424)

## [1.1.25]
* Added public API to pass EQP to the /token endpoint (#1406) 
* Return device join status regardless of SSO extension error(#1403)

## [1.1.24]
* Use base64URLEncoding for RSA modules (#1399)

## [1.1.23]
* Add helper for cross cloud B2B support in broker (#1370)
* Add support of "create" prompt (#1384)
* Fixed bug where background task was prematurely ended. (#1388)

## [1.1.22]
* Added more logging within common core throttling logic
* Updated release pipeline to publish public docs as last step (#1366)

## [1.1.21] - 2021-08-20
* Update release pipeline to publish public docs (#1359)

## [1.1.20] - 2021-07-19
* Migrated PR validation pipeline from Travis to Azure DevOps.(#1333)

## [1.1.19] - 2021-06-14: 
* Changed some of the logging levels from info to verbose per customer request
* Minimum Xcode version bumped to 12.2
* Add CCS hint header (#1300)

## [1.1.18] - 2021-05-17: 
* Minimum Xcode version bumped to 12.2
* Add CCS hint header (#1300)
* Update 'ts' field in AT Pop payload from string to number (#1310)

## [1.1.17] - 2021-04-19
* Added telemetry for different token refresh timing

## [1.1.16] - 2021-03-19
* Support empty or nil access token in MSAL token response (#1256)
* Implement throttling. 

## [1.1.15] - 2021-02-19
* Mask EUII in logs (#1206)
* Fixes to ADO release pipeline. (#1236)
* Fixed required attributes in SHR of AT Pop. (#1267)

## [1.1.14] - 2021-01-19
* Removed identity core classes from public api (#1158).
* Fixed possible deadlock caused by thread explosion (#1175)
* Added pipeline configuration to generate framework for SPM & automate MSAL release (#1194)
* Extend iOS background tasks to silent and interactive requests
* Change order of FRT/MRRT lookup for silent token refreshes

## [1.1.13] - 2020-12-04
* Adding nil check before assigning error when developers try to get account by username from MSALPublicClientApplication, this will help to prevent a crash when passing in nil as error ponter from the API

## [1.1.12] - 2020-12-02
* Added cross-cloud B2B support.
* Fixed logic to handle links that open in new tab for embedded webview.
* AccountForUsername from MSALPublicClientApplication will return nil back when username is nil or empty, error will be provided if a valid error pointer is passed in via this API
* Updated user guide to provide a sample Swift & ObjC code for querying a specific account and return token silently when multiple accounts are present in the cache. 
* Added client-side fix for the known ADFS PKeyAuth issue. (#1150)

## [1.1.11] - 2020-10-16
* Enabled PKeyAuth via UserAgent String on MacOS 
* Added a public API for both iOS and MacOS that returns a default recommended WKWebview
configuration settings. This API can be found in MSALWebviewParameters.h, along with an
example of usage. 
* Updated MSAL iOS/MacOS test apps to use aforementioned API to generate a default WKWebview object with recommended default settings for the PassedIn mode.
* Add public interface for asymmetric key/factory for cpp djinni interface
* Update RSA signing code and add conditional check for supported iOS/osx platforms.
* Update repo pipelines running on Xcode 12
* Return private key attributes on key pair generation.
* Bring in latest from dev branch for iOS 14 build


## [1.1.10] - 2020-09-21
* Fixed account filtering logic by accountId or username where accounts are queried from multiple sources.
* Fixed isSSOAccount flag on the MSALAccount when MSAL reads accounts from multiple sources.

## [1.1.9] - 2020-09-16
* Ignore duplicate certificate authentication challenge in system webview.
* Make webview parameters optional in MSALSignoutParameters #1086
* Support wiping external account #1085
* Normalize account ID for cache lookups (#1084)
* Add documentation for Proof-of-Possession for Access tokens.
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
* Add a flag to disable logger queue.

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
