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

final class MSALNativeAuthFlowErrorTests: XCTestCase {

    // MARK: - Classification booleans

    func test_isNotImplemented_onlyTrueForNotImplementedType() {
        assertClassification(matchingType: .notImplemented) { $0.isNotImplemented }
    }

    func test_isUserNotFound_onlyTrueForUserNotFoundType() {
        assertClassification(matchingType: .userNotFound) { $0.isUserNotFound }
    }

    func test_isInvalidCode_onlyTrueForInvalidCodeType() {
        assertClassification(matchingType: .invalidCode) { $0.isInvalidCode }
    }

    func test_isInvalidPassword_onlyTrueForInvalidPasswordType() {
        assertClassification(matchingType: .invalidPassword) { $0.isInvalidPassword }
    }

    func test_isInvalidCredentials_onlyTrueForInvalidCredentialsType() {
        assertClassification(matchingType: .invalidCredentials) { $0.isInvalidCredentials }
    }

    func test_isInvalidUsername_onlyTrueForInvalidUsernameType() {
        assertClassification(matchingType: .invalidUsername) { $0.isInvalidUsername }
    }

    func test_isUserDoesNotHavePassword_onlyTrueForUserDoesNotHavePasswordType() {
        assertClassification(matchingType: .userDoesNotHavePassword) { $0.isUserDoesNotHavePassword }
    }

    func test_isUserAlreadyExists_onlyTrueForUserAlreadyExistsType() {
        assertClassification(matchingType: .userAlreadyExists) { $0.isUserAlreadyExists }
    }

    func test_isInvalidChallenge_onlyTrueForInvalidChallengeType() {
        assertClassification(matchingType: .invalidChallenge) { $0.isInvalidChallenge }
    }

    func test_isAuthMethodBlocked_onlyTrueForAuthMethodBlockedType() {
        assertClassification(matchingType: .authMethodBlocked) { $0.isAuthMethodBlocked }
    }

    func test_isVerificationContactBlocked_onlyTrueForVerificationContactBlockedType() {
        assertClassification(matchingType: .verificationContactBlocked) { $0.isVerificationContactBlocked }
    }

    func test_isInvalidInput_onlyTrueForInvalidInputType() {
        assertClassification(matchingType: .invalidInput) { $0.isInvalidInput }
    }

    // MARK: - Browser / general flags forwarded to the base error

    func test_browserRequiredType_setsIsBrowserRequired() {
        let error = MSALNativeAuthFlowError(type: .browserRequired)
        XCTAssertTrue(error.isBrowserRequired)
        XCTAssertFalse(error.isGeneralError)
    }

    func test_generalErrorType_setsIsGeneralError() {
        let error = MSALNativeAuthFlowError(type: .generalError)
        XCTAssertTrue(error.isGeneralError)
        XCTAssertFalse(error.isBrowserRequired)
    }

    // MARK: - errorDescription

    func test_errorDescription_usesProvidedDescriptionWhenPresent() {
        let error = MSALNativeAuthFlowError(type: .invalidCode, errorDescription: "custom message")
        XCTAssertEqual(error.errorDescription, "custom message")
    }

    func test_errorDescription_fallsBackToTypeMessageWhenNoDescription() {
        XCTAssertEqual(MSALNativeAuthFlowError(type: .notImplemented).errorDescription, MSALNativeAuthErrorMessage.delegateNotImplementedV2)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .userNotFound).errorDescription, MSALNativeAuthErrorMessage.userNotFound)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidCode).errorDescription, MSALNativeAuthErrorMessage.invalidCode)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidPassword).errorDescription, MSALNativeAuthErrorMessage.invalidPassword)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidCredentials).errorDescription, MSALNativeAuthErrorMessage.invalidCredentials)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidUsername).errorDescription, MSALNativeAuthErrorMessage.invalidUsername)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .userDoesNotHavePassword).errorDescription, MSALNativeAuthErrorMessage.userDoesNotHavePassword)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .userAlreadyExists).errorDescription, MSALNativeAuthErrorMessage.userAlreadyExists)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidChallenge).errorDescription, MSALNativeAuthErrorMessage.invalidChallenge)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .authMethodBlocked).errorDescription, MSALNativeAuthErrorMessage.authMethodBlocked)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .verificationContactBlocked).errorDescription, MSALNativeAuthErrorMessage.verificationContactBlocked)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .invalidInput).errorDescription, MSALNativeAuthErrorMessage.invalidInput)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .browserRequired).errorDescription, MSALNativeAuthErrorMessage.browserRequired)
        XCTAssertEqual(MSALNativeAuthFlowError(type: .generalError).errorDescription, MSALNativeAuthErrorMessage.generalError)
    }

    // MARK: - Initializers

    func test_designatedInit_preservesCorrelationIdAndErrorCodes() {
        let correlationId = UUID()
        let error = MSALNativeAuthFlowError(type: .invalidCode, errorCodes: [50034], correlationId: correlationId)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, [50034])
    }

    func test_convenienceInit_generatesCorrelationId() {
        let error = MSALNativeAuthFlowError(type: .invalidCode)
        XCTAssertNotNil(error.correlationId)
    }

    // MARK: - Helpers

    private func assertClassification(
        matchingType: MSALNativeAuthFlowError.ErrorType,
        _ predicate: (MSALNativeAuthFlowError) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for type in MSALNativeAuthFlowError.ErrorType.allCases {
            let error = MSALNativeAuthFlowError(type: type)
            XCTAssertEqual(predicate(error), type == matchingType, "type \(type)", file: file, line: line)
        }
    }
}
