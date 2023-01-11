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

final class MSALNativeTokenResponseValidatorTests: XCTestCase {

    // MARK: - Variables

    private var sut: MSALNativeTokenResponseValidator!
    private var defaultValidatorMock: DefaultValidatorMock!

    // MARK: - Setup

    override func setUpWithError() throws {
        defaultValidatorMock = DefaultValidatorMock()

        sut = .init(
            defaultValidator: defaultValidatorMock,
            factory: MSIDOauth2Factory(),
            context: ContextStub(),
            configuration: MSIDConfiguration(),
            accountIdentifier: MSIDAccountIdentifier(displayableId: "aDisplayableId", homeAccountId: "home.account.id")
        )
    }

    // MARK: - ValidateResponse tests

    func test_validateResponse_returns_tokenResult() throws {
        let response = MSIDAADTokenResponse()
        defaultValidatorMock.shouldReturnTokenResult = true

        let result = try sut.validateResponse(response)
        XCTAssertNotNil(result)
    }

    func test_validateResponse_returns_intune_policy_error() throws {
        let response = MSIDAADTokenResponse()
        defaultValidatorMock.shouldReturnServerProtectionPoliciesRequiredError = true

        XCTAssertThrowsError(try sut.validateResponse(response)) {
            XCTAssertEqual($0 as? MSALNativeError, .serverProtectionPoliciesRequired(homeAccountId: "home.account.id"))
        }
    }

    func test_validateResponse_returns_generic_error() throws {
        let response = MSIDAADTokenResponse()
        defaultValidatorMock.shouldThrowGenericError = true

        XCTAssertThrowsError(try sut.validateResponse(response)) {
            XCTAssertEqual($0 as? MSALNativeError, .validationError)
        }
    }

    // MARK: - ValidateAccount tests

    func test_validateAccount_successfully() throws {
        var error: NSError?
        defaultValidatorMock.shouldReturnValidAccount = true
        XCTAssertTrue(sut.validateAccount(with: MSIDTokenResult(), error: &error))
    }

    func test_validateAccount_error() throws {
        var error: NSError?
        defaultValidatorMock.shouldReturnValidAccount = false
        XCTAssertFalse(sut.validateAccount(with: MSIDTokenResult(), error: &error))
    }
}

private class DefaultValidatorMock: MSIDTokenResponseValidator {

    var shouldReturnTokenResult = false
    var shouldReturnServerProtectionPoliciesRequiredError = false
    var shouldThrowGenericError = false
    var shouldReturnValidAccount = false

    private let tokenResult = MSIDTokenResult()

    override func validate(
        _ tokenResponse: MSIDTokenResponse,
        oauthFactory factory: MSIDOauth2Factory,
        configuration: MSIDConfiguration,
        requestAccount accountIdentifier: MSIDAccountIdentifier?,
        correlationID: UUID,
        error: NSErrorPointer
    ) -> MSIDTokenResult? {

        if shouldReturnTokenResult {
            return tokenResult
        } else if shouldReturnServerProtectionPoliciesRequiredError {
            let serverProtectionPoliciesError = NSError(
                domain: "aDomain",
                code: MSIDErrorCode.serverProtectionPoliciesRequired.rawValue
            )

            error?.pointee = serverProtectionPoliciesError
            
            return nil
        } else if shouldThrowGenericError {
            return nil
        }

        return tokenResult
    }

    override func validateAccount(
        _ accountIdentifier: MSIDAccountIdentifier,
        tokenResult: MSIDTokenResult,
        correlationID: UUID,
        error: NSErrorPointer
    ) -> Bool {
        shouldReturnValidAccount
    }
}

private class ContextStub: MSIDRequestContext {

    func correlationId() -> UUID! {
        .init()
    }

    func logComponent() -> String! {
        ""
    }

    func telemetryRequestId() -> String! {
        ""
    }

    func appRequestMetadata() -> [AnyHashable : Any]! {
        [:]
    }
}
