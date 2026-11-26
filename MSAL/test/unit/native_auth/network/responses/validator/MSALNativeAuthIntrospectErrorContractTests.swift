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

final class MSALNativeAuthIntrospectErrorContractTests: XCTestCase {
    private let correlationId = UUID()
    private let message = "Request cannot continue"
    private let codes = [90023, 90024]
    private let errorUri = "https://example.com/auth-error"

    func test_signInIntrospection_preservesServerDiagnosticsForEveryCaller() {
        let response = MSALNativeAuthSignInIntrospectResponseError(
            error: .invalidRequest,
            errorDescription: message,
            errorCodes: codes,
            errorURI: errorUri,
            correlationId: UUID()
        )
        let errors: [MSALNativeAuthSignInIntrospectValidatedErrorType] = [
            .invalidRequest(response), .expiredToken(response), .unexpectedError(response)
        ]

        for error in errors {
            let start = error.convertToSignInPasswordStartError(correlationId: correlationId)
            let password = error.convertToPasswordRequiredError(correlationId: correlationId)
            let verification = error.convertToVerifyCodeError(correlationId: correlationId)

            XCTAssertEqual(start.type, .generalError)
            XCTAssertEqual(password.type, .generalError)
            XCTAssertEqual(verification.type, .generalError)
            let convertedErrors: [MSALNativeAuthError] = [start, password, verification]
            for converted in convertedErrors {
                assertDiagnostics(converted, message: message, codes: codes, uri: errorUri)
            }
        }
    }

    func test_signInIntrospection_missingDiagnosticsUseGeneralMessageWithoutInventingServerDetails() {
        let response = MSALNativeAuthSignInIntrospectResponseError(error: .expiredToken)
        let errors: [MSALNativeAuthSignInIntrospectValidatedErrorType] = [
            .invalidRequest(response), .expiredToken(response), .unexpectedError(response), .unexpectedError(nil)
        ]

        for error in errors {
            let converted: [MSALNativeAuthError] = [
                error.convertToSignInPasswordStartError(correlationId: correlationId),
                error.convertToPasswordRequiredError(correlationId: correlationId),
                error.convertToVerifyCodeError(correlationId: correlationId)
            ]
            for result in converted {
                XCTAssertTrue(result.isGeneralError)
                assertDiagnostics(result, message: MSALNativeAuthErrorMessage.generalError, codes: [], uri: nil)
            }
        }
    }

    func test_signInIntrospection_redirectRequiresBrowserForEveryCaller() {
        let reasons: [String?] = ["Use browser authentication", nil]
        for reason in reasons {
            let error = MSALNativeAuthSignInIntrospectValidatedErrorType.redirect(reason: reason)
            let start = error.convertToSignInPasswordStartError(correlationId: correlationId)
            let password = error.convertToPasswordRequiredError(correlationId: correlationId)
            let verification = error.convertToVerifyCodeError(correlationId: correlationId)

            XCTAssertEqual(start.type, .browserRequired)
            XCTAssertEqual(password.type, .browserRequired)
            XCTAssertEqual(verification.type, .browserRequired)
            let convertedErrors: [MSALNativeAuthError] = [start, password, verification]
            for converted in convertedErrors {
                XCTAssertTrue(converted.isBrowserRequired)
                assertDiagnostics(converted, message: reason ?? MSALNativeAuthErrorMessage.browserRequired, codes: [], uri: nil)
            }
        }
    }

    func test_registrationIntrospection_preservesServerDiagnosticsForEveryCaller() {
        let response = MSALNativeAuthJITIntrospectResponseError(
            errorDescription: message,
            errorCodes: codes,
            errorURI: errorUri,
            correlationId: UUID()
        )
        let errors: [MSALNativeAuthJITIntrospectValidatedErrorType] = [.invalidRequest(response), .unexpectedError(response)]

        for error in errors {
            let start = error.convertToSignInPasswordStartError(correlationId: correlationId)
            let password = error.convertToPasswordRequiredError(correlationId: correlationId)
            let verification = error.convertToVerifyCodeError(correlationId: correlationId)

            XCTAssertEqual(start.type, .generalError)
            XCTAssertEqual(password.type, .generalError)
            XCTAssertEqual(verification.type, .generalError)
            let convertedErrors: [MSALNativeAuthError] = [start, password, verification]
            for converted in convertedErrors {
                assertDiagnostics(converted, message: message, codes: codes, uri: errorUri)
            }
        }
    }

    func test_registrationIntrospection_invalidRequestUsesEmptyDiagnosticsWhenServerOmitsThem() {
        let error = MSALNativeAuthJITIntrospectValidatedErrorType.invalidRequest(.init())
        let converted: [MSALNativeAuthError] = [
            error.convertToSignInPasswordStartError(correlationId: correlationId),
            error.convertToPasswordRequiredError(correlationId: correlationId),
            error.convertToVerifyCodeError(correlationId: correlationId)
        ]

        for result in converted {
            XCTAssertTrue(result.isGeneralError)
            assertDiagnostics(result, message: "", codes: [], uri: "")
        }
    }

    func test_registrationIntrospection_unexpectedErrorUsesGeneralMessageWithoutInventingServerDetails() {
        let responses: [MSALNativeAuthJITIntrospectResponseError?] = [.init(), nil]
        for response in responses {
            let error = MSALNativeAuthJITIntrospectValidatedErrorType.unexpectedError(response)
            let converted: [MSALNativeAuthError] = [
                error.convertToSignInPasswordStartError(correlationId: correlationId),
                error.convertToPasswordRequiredError(correlationId: correlationId),
                error.convertToVerifyCodeError(correlationId: correlationId)
            ]
            for result in converted {
                XCTAssertTrue(result.isGeneralError)
                assertDiagnostics(result, message: MSALNativeAuthErrorMessage.generalError, codes: [], uri: nil)
            }
        }
    }

    func test_registrationIntrospection_redirectRequiresBrowserForEveryCaller() {
        let reasons: [String?] = ["Registration requires browser", nil]
        for reason in reasons {
            let error = MSALNativeAuthJITIntrospectValidatedErrorType.redirect(reason: reason)
            let start = error.convertToSignInPasswordStartError(correlationId: correlationId)
            let password = error.convertToPasswordRequiredError(correlationId: correlationId)
            let verification = error.convertToVerifyCodeError(correlationId: correlationId)

            XCTAssertEqual(start.type, .browserRequired)
            XCTAssertEqual(password.type, .browserRequired)
            XCTAssertEqual(verification.type, .browserRequired)
            let convertedErrors: [MSALNativeAuthError] = [start, password, verification]
            for converted in convertedErrors {
                XCTAssertTrue(converted.isBrowserRequired)
                assertDiagnostics(converted, message: reason ?? MSALNativeAuthErrorMessage.browserRequired, codes: [], uri: nil)
            }
        }
    }

    private func assertDiagnostics(
        _ error: MSALNativeAuthError,
        message: String?,
        codes: [Int],
        uri: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(error.correlationId, correlationId, file: file, line: line)
        XCTAssertEqual(error.errorDescription, message, file: file, line: line)
        XCTAssertEqual(error.errorCodes, codes, file: file, line: line)
        XCTAssertEqual(error.errorUri, uri, file: file, line: line)
    }
}
