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

final class MSALNativeAuthTokenValidatedErrorTypeTests: XCTestCase {
    
    private typealias sut = MSALNativeAuthTokenValidatedErrorType
    private let testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let testCorrelationId = UUID()
    private let testErrorUri = "test error uri"
    private var apiErrorStub: MSALNativeAuthTokenResponseError {
        .init(
            error: .invalidRequest,
            subError: .attributeValidationFailed,
            errorDescription: testDescription,
            errorCodes: testErrorCodes,
            errorURI: testErrorUri,
            correlationId: testCorrelationId
        )
    }

    func test_accessTokenConversion_preservesDiagnosticsAndDistinguishesRefreshExpiry() {
        let cases: [(sut, RetrieveAccessTokenError.ErrorType)] = [
            (.expiredToken(apiErrorStub), .generalError), (.authorizationPending(apiErrorStub), .generalError),
            (.slowDown(apiErrorStub), .generalError), (.unauthorizedClient(apiErrorStub), .generalError),
            (.unsupportedChallengeType(apiErrorStub), .generalError), (.invalidScope(apiErrorStub), .generalError),
            (.invalidRequest(apiErrorStub), .generalError), (.unexpectedError(apiErrorStub), .generalError),
            (.expiredRefreshToken(apiErrorStub), .refreshTokenExpired), (.userNotFound(apiErrorStub), .generalError),
            (.invalidPassword(apiErrorStub), .generalError), (.invalidOOBCode(apiErrorStub), .generalError)
        ]
        let requestCorrelationId = UUID()
        for (input, expectedType) in cases {
            let error = input.convertToRetrieveAccessTokenError(correlationId: requestCorrelationId)
            XCTAssertEqual(error.type, expectedType)
            XCTAssertEqual(error.isRefreshTokenExpired, expectedType == .refreshTokenExpired)
            XCTAssertEqual(error.errorDescription, testDescription)
            XCTAssertEqual(error.correlationId, requestCorrelationId)
            XCTAssertEqual(error.errorCodes, testErrorCodes)
            XCTAssertEqual(error.errorUri, testErrorUri)
        }
    }

    func test_accessTokenConversion_usesExactGeneralAndBrowserFallbacks() {
        let general = sut.generalError(apiErrorStub).convertToRetrieveAccessTokenError(correlationId: testCorrelationId)
        XCTAssertTrue(general.isGeneralError)
        XCTAssertEqual(general.errorDescription, MSALNativeAuthErrorMessage.generalError)
        XCTAssertEqual(general.errorCodes, [])
        XCTAssertNil(general.errorUri)
        let reasons: [String?] = ["Use interactive authentication", nil]
        for reason in reasons {
            let error = sut.redirect(reason: reason).convertToRetrieveAccessTokenError(correlationId: testCorrelationId)
            XCTAssertTrue(error.isBrowserRequired)
            XCTAssertFalse(error.isGeneralError)
            XCTAssertEqual(error.errorDescription, reason ?? MSALNativeAuthErrorMessage.browserRequired)
            XCTAssertEqual(error.correlationId, testCorrelationId)
            XCTAssertEqual(error.errorCodes, [])
            XCTAssertNil(error.errorUri)
        }
    }

    func test_codeVerificationConversion_preservesDiagnosticsAndInvalidCodeClassification() {
        let cases: [(sut, VerifyCodeError.ErrorType)] = [
            (.invalidOOBCode(apiErrorStub), .invalidCode), (.expiredToken(apiErrorStub), .generalError),
            (.authorizationPending(apiErrorStub), .generalError), (.slowDown(apiErrorStub), .generalError),
            (.unauthorizedClient(apiErrorStub), .generalError), (.unsupportedChallengeType(apiErrorStub), .generalError),
            (.invalidScope(apiErrorStub), .generalError), (.expiredRefreshToken(apiErrorStub), .generalError),
            (.userNotFound(apiErrorStub), .generalError), (.invalidPassword(apiErrorStub), .generalError),
            (.invalidRequest(apiErrorStub), .generalError), (.unexpectedError(apiErrorStub), .generalError)
        ]
        let requestCorrelationId = UUID()
        for (input, expectedType) in cases {
            let error = input.convertToVerifyCodeError(correlationId: requestCorrelationId)
            XCTAssertEqual(error.type, expectedType)
            XCTAssertEqual(error.isInvalidCode, expectedType == .invalidCode)
            XCTAssertEqual(error.errorDescription, testDescription)
            XCTAssertEqual(error.correlationId, requestCorrelationId)
            XCTAssertEqual(error.errorCodes, testErrorCodes)
            XCTAssertEqual(error.errorUri, testErrorUri)
        }
    }

    func test_codeVerificationConversion_usesExactGeneralAndBrowserFallbacks() {
        let general = sut.generalError(apiErrorStub).convertToVerifyCodeError(correlationId: testCorrelationId)
        XCTAssertTrue(general.isGeneralError)
        XCTAssertEqual(general.errorDescription, MSALNativeAuthErrorMessage.generalError)
        XCTAssertEqual(general.errorCodes, [])
        XCTAssertNil(general.errorUri)
        let reasons: [String?] = ["Use interactive authentication", nil]
        for reason in reasons {
            let error = sut.redirect(reason: reason).convertToVerifyCodeError(correlationId: testCorrelationId)
            XCTAssertTrue(error.isBrowserRequired)
            XCTAssertEqual(error.errorDescription, reason ?? MSALNativeAuthErrorMessage.browserRequired)
            XCTAssertEqual(error.correlationId, testCorrelationId)
            XCTAssertEqual(error.errorCodes, [])
            XCTAssertNil(error.errorUri)
        }
    }

    // MARK: - convertToSignInPasswordStartError tests
    
    func test_convertToSignInPasswordStartError_generalError() {

        let error = sut.generalError(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_expiredToken() {
        let error = sut.expiredToken(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_expiredRefreshToken() {
        let error = sut.expiredRefreshToken(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_unauthorizedClient() {
        let error = sut.unauthorizedClient(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_invalidRequest() {
        let error = sut.invalidRequest(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_invalidServerResponse() {
        let error = sut.unexpectedError(.init(apiErrorStub)).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_userNotFound() {
        let error = sut.userNotFound(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_invalidPassword() {
        let error = sut.invalidPassword(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .invalidCredentials)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_invalidOOBCode() {
        let error = sut.invalidOOBCode(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_invalidScope() {
        let error = sut.invalidScope(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_authorizationPending() {
        let error = sut.authorizationPending(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_convertToSignInPasswordStartError_redirect() {
        let reason = "reason"
        let error = sut.redirect(reason: reason).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .browserRequired)
        XCTAssertEqual(error.errorDescription, reason)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorCodes.count, 0)
        XCTAssertNil(error.errorUri)
    }
    
    func test_convertToSignInPasswordStartError_slowDown() {
        let error = sut.slowDown(apiErrorStub).convertToSignInPasswordStartError(correlationId: testCorrelationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
}
