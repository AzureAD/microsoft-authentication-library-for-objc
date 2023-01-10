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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

final class MSALNativeTokenResponseHandlerTests: XCTestCase {

    // MARK: - Variables

    private var sut: MSALNativeTokenResponseHandler!

    private static let loggerSpy = LoggerSpy()
    private var tokenResponseValidatorMock: NativeTokenResponseValidatorMock!
    private let context: MSIDRequestContext = MSIDBasicContext()
    private let accountIdentifier = MSIDAccountIdentifier(displayableId: "aDisplayableId", homeAccountId: "home.account.id")!

    // MARK: - Setup

    override func setUpWithError() throws {
        tokenResponseValidatorMock = NativeTokenResponseValidatorMock(context: context, accountIdentifier: accountIdentifier)

        sut = MSALNativeTokenResponseHandler(
            tokenResponseValidator: tokenResponseValidatorMock,
            tokenCache: NativeCacheStub(),
            accountIdentifier: accountIdentifier,
            context: context,
            configuration: .init()
        )
    }

    override func tearDown() {
        Self.loggerSpy.reset()
        super.tearDown()
    }

    // MARK: - tests

    func test_handle_tokenResponse_successfully() throws {
        XCTAssertNoThrow(try sut.handle(tokenResponse: .init(), validateAccount: false))
    }

    func test_handleTokenResponse_returns_generic_error() throws {
        tokenResponseValidatorMock.shouldThrowGenericError = true

        XCTAssertThrowsError(try sut.handle(tokenResponse: .init(), validateAccount: false)) {
            XCTAssertEqual($0 as? MSALNativeError, .validationError)
        }
    }

    func test_handleTokenResponse_withAccountValidation_logs_data() throws {
        let expectation = expectation(description: "test_handleTokenResponse_withAccountValidation_logs_data_expectation")
        expectation.expectedFulfillmentCount = 2

        Self.loggerSpy.expectation = expectation
        Self.loggerSpy.expectedMessage = "Validated result account with result 1, old account Masked(null), new account Masked(null)"

        _ = try? sut.handle(tokenResponse: .init(), validateAccount: true)

        wait(for: [expectation], timeout: 1)
    }

    func test_handleTokenResponse_returns_intune_error_logs_data() throws {
        let expectation = expectation(description: "test_handleTokenResponse_returns_intune_error_logs_data_expectation")
        expectation.expectedFulfillmentCount = 2

        Self.loggerSpy.expectation = expectation
        Self.loggerSpy.expectedMessage = "Received Protection Policy Required error."

        tokenResponseValidatorMock.shouldThrowIntuneError = true

        XCTAssertThrowsError(try sut.handle(tokenResponse: .init(), validateAccount: false)) {
            XCTAssertEqual($0 as? MSALNativeError, .serverProtectionPoliciesRequired(homeAccountId: nil))
        }

        wait(for: [expectation], timeout: 1)
    }
}

private class NativeTokenResponseValidatorMock: MSALNativeTokenResponseValidating {

    var shouldThrowGenericError = false
    var shouldThrowIntuneError = false

    let defaultValidator: MSIDTokenResponseValidator = .init()
    let factory: MSIDOauth2Factory = .init()
    let context: MSIDRequestContext
    let configuration: MSIDConfiguration = .init()
    let accountIdentifier: MSIDAccountIdentifier

    init(context: MSIDRequestContext, accountIdentifier: MSIDAccountIdentifier) {
        self.context = context
        self.accountIdentifier = accountIdentifier
    }

    func validateResponse(_ tokenResponse: MSIDTokenResponse) throws -> MSIDTokenResult {

        if shouldThrowGenericError {
            throw MSALNativeError.validationError
        }

        if shouldThrowIntuneError {
            throw MSALNativeError.serverProtectionPoliciesRequired(homeAccountId: nil)
        }

        let account = MSIDAccount()
        account.accountIdentifier = .init(displayableId: "aDisplayableId", homeAccountId: "")

        let tokenResult = MSIDTokenResult(
            accessToken: .init(),
            refreshToken: nil,
            idToken: "",
            account: account,
            authority: try! .init(url: .init(string: DEFAULT_TEST_RESOURCE)!, context: nil),
            correlationId: .init(),
            tokenResponse: nil
        )!

        return tokenResult
    }

    func validateAccount(with tokenResult: MSIDTokenResult) -> Bool {
        true
    }
}

private class LoggerSpy {

    var counter = 0
    var expectation: XCTestExpectation?
    var expectedMessage: String!

    init() {
        MSALGlobalConfig.loggerConfig.setLogCallback(callback)
    }

    func reset() {
        counter = 0
        expectation = nil
        expectedMessage = nil
    }

    private func callback(_ logLevel: MSALLogLevel, _ message: String?, _ containsPII: Bool) {
        guard let expectation = expectation else { return }

        expectation.fulfill()

        counter += 1

        // We want to check the 2nd log inside MSALNativeTokenResponseHandler.handle() - the 1st one is just an info log
        if counter == 2 {
            let result = message!.contains(expectedMessage)
            XCTAssertTrue(result)
        }
    }
}

private class NativeCacheStub: MSALNativeAuthCacheInterface {

    func getTokens(accountIdentifier: MSIDAccountIdentifier, configuration: MSIDConfiguration, context: MSIDRequestContext) throws -> MSAL.MSALNativeAuthTokens {
        .init(idToken: nil, accessToken: nil, refreshToken: nil)
    }

    func getAccount(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, context: MSIDRequestContext) throws -> MSIDAccount? {
        .init()
    }

    func saveTokensAndAccount(tokenResult: MSIDTokenResponse, configuration: MSIDConfiguration, context: MSIDRequestContext) throws {
    }

    func removeTokens(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
    }

    func clearCache(accountIdentifier: MSIDAccountIdentifier, authority: MSIDAuthority, clientId: String, context: MSIDRequestContext) throws {
    }
}
