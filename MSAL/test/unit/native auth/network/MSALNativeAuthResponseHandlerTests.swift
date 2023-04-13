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

final class MSALNativeAuthResponseHandlerTests: MSALNativeAuthTestCase {

    // MARK: - Variables

    private var sut: MSALNativeAuthResponseHandler!

    private var tokenResponseValidatorMock: MSALNativeTokenResponseValidatorMock!
    private let context: MSIDRequestContext = MSIDBasicContext()
    private let accountIdentifier = MSIDAccountIdentifier(displayableId: "aDisplayableId", homeAccountId: "home.account.id")!
    private let configuration = MSIDConfiguration()

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        tokenResponseValidatorMock = MSALNativeTokenResponseValidatorMock(context: context, accountIdentifier: accountIdentifier)

        sut = MSALNativeAuthResponseHandler(
            tokenResponseValidator: tokenResponseValidatorMock
        )
    }

    // MARK: - tests

    func test_handle_tokenResponse_successfully() throws {
        XCTAssertNoThrow(try sut.handle(context: context, accountIdentifier: accountIdentifier, tokenResponse: .init(), configuration: configuration, validateAccount: false))
    }

    func test_handleTokenResponse_returns_generic_error() throws {
        tokenResponseValidatorMock.shouldThrowGenericError = true

        XCTAssertThrowsError(try sut.handle(context: context, accountIdentifier: accountIdentifier, tokenResponse: .init(), configuration: configuration, validateAccount: false)) {
            XCTAssertEqual($0 as? MSALNativeAuthError, .validationError)
        }
    }

    func test_handleTokenResponse_withAccountValidation_logs_data() throws {
        let expectation = expectation(description: "Log account validation")
        expectation.expectedFulfillmentCount = 2

        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskAllPII
        Self.logger.expectation = expectation

        _ = try? sut.handle(context: context, accountIdentifier: accountIdentifier, tokenResponse: .init(), configuration: configuration, validateAccount: true)

        wait(for: [expectation], timeout: 1)

        let resultingLog = Self.logger.messages[1] as! String
        XCTAssertTrue(resultingLog.contains(
            "Validated account with result 1, old account Masked(null), new account Masked(null)")
        )
    }
}

private class MSALNativeTokenResponseValidatorMock: MSALNativeAuthTokenResponseValidating {
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

    func validateResponse(tokenResponse: MSIDTokenResponse, context: MSIDRequestContext, configuration: MSIDConfiguration, accountIdentifier: MSIDAccountIdentifier) throws -> MSIDTokenResult {
        if shouldThrowGenericError {
            throw MSALNativeAuthError.validationError
        }

        if shouldThrowIntuneError {
            throw MSALNativeAuthError.serverProtectionPoliciesRequired(homeAccountId: nil)
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
    
    func validateAccount(with tokenResult: MSIDTokenResult, context: MSIDRequestContext, configuration: MSIDConfiguration, accountIdentifier: MSIDAccountIdentifier, error: inout NSError?) -> Bool {
        true
    }
}
