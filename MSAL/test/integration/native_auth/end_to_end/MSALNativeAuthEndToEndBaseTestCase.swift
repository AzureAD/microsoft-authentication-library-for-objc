//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest
import MSAL

final class MSALNativeAuthEmailOTPUserPool {
    enum ConfigurationError: LocalizedError, Equatable {
        case missingOrEmptyValue(String)
        case duplicateValues

        var errorDescription: String? {
            switch self {
            case .missingOrEmptyValue(let key):
                return "Email OTP username configuration '\(key)' is missing or empty."
            case .duplicateValues:
                return "Email OTP username configuration contains duplicate values."
            }
        }
    }

    private let usernames: [String]
    private let lock = NSLock()
    private var nextIndex = 0

    init(usernames: [String]) {
        precondition(!usernames.isEmpty)
        self.usernames = usernames
    }

    static func make(configuration: [String: String], keys: [String]) throws -> MSALNativeAuthEmailOTPUserPool {
        var usernames = [String]()

        for key in keys {
            guard let value = configuration[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                throw ConfigurationError.missingOrEmptyValue(key)
            }

            usernames.append(value)
        }

        guard Set(usernames).count == usernames.count else {
            throw ConfigurationError.duplicateValues
        }

        return MSALNativeAuthEmailOTPUserPool(usernames: usernames)
    }

    func nextUsername() -> String {
        lock.lock()
        defer { lock.unlock() }

        let username = usernames[nextIndex]
        nextIndex = (nextIndex + 1) % usernames.count
        return username
    }
}

enum MSALNativeAuthEmailOTPErrorClassifier {
    private static let throttleErrorCode = 701014

    static func isThrottleError(errorCodes: [Int], errorDescription: String?) -> Bool {
        if errorCodes.contains(throttleErrorCode) {
            return true
        }

        return errorDescription?.contains("AADSTS\(throttleErrorCode)") == true
    }
}

class MSALNativeAuthEndToEndBaseTestCase: XCTestCase {
    private class Constants {
        static let nativeAuthKey = "native_auth"
        static let clientIdEmailPasswordKey = "email_password_client_id"
        static let clientIdEmailCodeKey = "email_code_client_id"
        static let clientIdEmailPasswordAttributesKey = "email_password_attributes_client_id"
        static let clientIdEmailCodeAttributesKey = "email_code_attributes_client_id"
        static let tenantSubdomainKey = "tenant_subdomain"
        static let tenantIdKey = "tenant_id"
        static let signInEmailPasswordUsernameKey = "sign_in_email_password_username"
        static let signInEmailPasswordMFAUsernameKey = "sign_in_email_password_mfa_username"
        static let signInEmailPasswordMFANoDefaultAuthMethodUsernameKey = "sign_in_email_password_mfa_no_default_username"
        static let signInEmailCodeUsernameKey = "sign_in_email_code_username"
        static let emailOTPUsernameKeys = [
            signInEmailCodeUsernameKey,
            "sign_in_email_code_username_2",
            "sign_in_email_code_username_3"
        ]
        #if !os(macOS)
        static let resetPasswordUsernameKey = "reset_password_username"
        #else
        static let resetPasswordUsernameKey = "reset_password_username_macos"
        #endif
        static let emailProviderPasswordKey = "email_provider_password"
    }
    
    let correlationId = UUID()
    
    static var confFileContent: [String: Any]? = nil
    static var nativeAuthConfFileContent: [String: String]? = nil
    private static let emailOTPUserPoolLock = NSLock()
    private static var emailOTPUserPool: MSALNativeAuthEmailOTPUserPool?
    // Per-test-case instance so mail.tm state (token, checkpoint) is isolated to a single test's
    // lifecycle. markCheckpoint() and the subsequent readOtpCode() run on the same instance within
    // a test, while parallel test runs never share mutable state.
    private let codeRetriever = MSALNativeAuthEmailCodeRetriever()
    private var emailOTPUsername: String?
    
    override class func setUp() {
        super.setUp()
        
        guard let confURL = Bundle(for: Self.self).url(forResource: "conf", withExtension: "json"), let configurationData = try? Data(contentsOf: confURL) else {
            XCTFail("conf.json file not found")
            return
        }
        guard let confFile = try? JSONSerialization.jsonObject(with: configurationData, options: []) as? [String: Any] else {
            XCTFail("conf.json file can't be parsed.")
            return
        }
        confFileContent = confFile
        if let configurationFileContent = confFile[Constants.nativeAuthKey] as? [String: String] {
            nativeAuthConfFileContent = configurationFileContent
        } else {
            XCTFail("native_auth section in conf.json file not found")
        }
    }

    private static func configuredEmailOTPUserPool() throws -> MSALNativeAuthEmailOTPUserPool {
        emailOTPUserPoolLock.lock()
        defer { emailOTPUserPoolLock.unlock() }

        if let emailOTPUserPool {
            return emailOTPUserPool
        }

        let configuration = try XCTUnwrap(
            nativeAuthConfFileContent,
            "Native Auth configuration is unavailable."
        )
        let userPool = try MSALNativeAuthEmailOTPUserPool.make(
            configuration: configuration,
            keys: Constants.emailOTPUsernameKeys
        )
        emailOTPUserPool = userPool
        return userPool
    }
    
    func initialisePublicClientApplication(
        clientIdType: ClientIdType = .password,
        challengeTypes: MSALNativeAuthChallengeTypes = [.OOB, .password],
        capabilities: MSALNativeAuthCapabilities = [.mfaRequired, .registrationRequired],
        customAuthorityURLFormat: AuthorityURLFormat? = nil
    ) -> MSALNativeAuthPublicClientApplication? {
        let clientIdKey = getClientIdKey(type: clientIdType)
        guard let clientId = MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[clientIdKey] as? String else {
            XCTFail("ClientId not found in conf.json")
            return nil
        }
        
        guard let tenantSubdomain = MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.tenantSubdomainKey] as? String else {
            XCTFail("TenantSubdomain not found in conf.json")
            return nil
        }
        
        guard let tenantId = MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.tenantIdKey] as? String else {
            XCTFail("TenantId not found in conf.json")
            return nil
        }
        
        
        if let customAuthorityURLFormat = customAuthorityURLFormat {
            let customSubdomain = getAuthorityURLString(
                tenantSubdomain: tenantSubdomain,
                tenantId: tenantId,
                format: customAuthorityURLFormat
            )
            
            let authority = try! MSALCIAMAuthority(
                url: URL(string: customSubdomain)!,
                validateFormat: false
            )
            
            let configuration = MSALNativeAuthPublicClientApplicationConfig(clientId: clientId, authority: authority, challengeTypes: challengeTypes)
            configuration.capabilities = capabilities
           
            return try? MSALNativeAuthPublicClientApplication(
                nativeAuthConfiguration: configuration
            )
        } else if let configuration = try? MSALNativeAuthPublicClientApplicationConfig(clientId: clientId, tenantSubdomain: tenantSubdomain, challengeTypes: challengeTypes) {
            configuration.capabilities = capabilities
            return try? MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: configuration)
        } else {
            return nil
        }
    }
    
    func createEmailProviderAccount(password: String) async -> String {
        
        guard let address = await codeRetriever.createAuthenticatedAccount(password: password) else {
            XCTFail("Failed to create/authenticate email provider account")
            return ""
        }
        return address
    }
    
    func generateSignUpRandomEmail() -> String {
        return codeRetriever.generateRandomEmailAddress()
    }

    func generateRandomPassword() -> String {
        return "password.\(Date().timeIntervalSince1970)"
    }

    func retrieveCodeFor(email: String, password: String? = nil) async -> String? {
        guard let password = password ?? retrieveEmailProviderPassword() else {
            XCTFail("email_provider_password not found in conf.json")
            return nil
        }
        let connected = await codeRetriever.connectToExistingAccount(address: email, password: password)
        guard connected else {
            XCTFail("Could not authenticate with mail.tm for the email specified")
            return nil
        }
        return await codeRetriever.readOtpCode()
    }

    /// Records a checkpoint on the test-case's mail.tm client. Call this immediately before triggering
    /// an action that sends an OTP email so `retrieveCodeFor` ignores older messages.
    func markEmailCheckpoint() {
        codeRetriever.markCheckpoint()
    }

    func retrieveEmailProviderPassword() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.emailProviderPasswordKey]
    }

    func retrieveUsernameForSignInCode() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.signInEmailCodeUsernameKey]
    }

    func emailOTPUsernameForCurrentTest() throws -> String {
        try requireEmailOTPTestSupport()

        if let emailOTPUsername {
            return emailOTPUsername
        }

        let userPool = try Self.configuredEmailOTPUserPool()
        let username = userPool.nextUsername()
        emailOTPUsername = username
        return username
    }

    func requireEmailOTPTestSupport() throws {
//        #if os(macOS)
//        throw XCTSkip("Email OTP E2E tests run on iOS only.")
//        #endif
    }

    func skipIfEmailOTPThrottled(
        _ error: MSALNativeAuthError?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let error, isEmailOTPThrottleError(error) else {
            return false
        }

        XCTSkip(
            "AADSTS701014: CIAM could not generate another email OTP. Correlation ID: \(error.correlationId)",
            file: file,
            line: line
        )
        return true
    }

    private func isEmailOTPThrottleError(_ error: MSALNativeAuthError) -> Bool {
        return MSALNativeAuthEmailOTPErrorClassifier.isThrottleError(
            errorCodes: error.errorCodes,
            errorDescription: error.errorDescription
        )
    }

    func retrieveUsernameForSignInUsernameAndPassword() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.signInEmailPasswordUsernameKey]
    }
    
    func retrieveUsernameForSignInUsernamePasswordAndMFA() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.signInEmailPasswordMFAUsernameKey]
    }
    
    func retrieveUsernameForSignInUsernamePasswordAndMFANoDefaultAuthMethod() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.signInEmailPasswordMFANoDefaultAuthMethodUsernameKey]
    }
    
    func retrieveUsernameForResetPassword() -> String? {
        return MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[Constants.resetPasswordUsernameKey]
    }
    
    func fulfillment(of expectations: [XCTestExpectation], timeout seconds: TimeInterval = 40) async {
        await fulfillment(of: expectations, timeout: seconds, enforceOrder: false)
    }
    
    private func getClientIdKey(type: ClientIdType) -> String {
        switch type {
        case .password:
            return Constants.clientIdEmailPasswordKey
        case .passwordAndAttributes:
            return Constants.clientIdEmailPasswordAttributesKey
        case .code:
            return Constants.clientIdEmailCodeKey
        case .codeAndAttributes:
            return Constants.clientIdEmailCodeAttributesKey
        }
    }
    
    private func getAuthorityURLString(tenantSubdomain: String, tenantId: String, format: AuthorityURLFormat) -> String {
        switch format {
        case .tenantSubdomainShortVersion:
            return String(format: "https://%@.ciamlogin.com/", tenantSubdomain)
        case .tenantSubdomainLongVersion:
            return String(format: "https://%@.ciamlogin.com/%@.onmicrosoft.com", tenantSubdomain, tenantSubdomain)
        case .tenantSubdomainTenantId:
            return String(format: "https://%@.ciamlogin.com/%@", tenantSubdomain, tenantId)
        }
    }
}
