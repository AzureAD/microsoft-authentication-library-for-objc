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
@testable import SDKSampleApp

class FieldValidatorTests: XCTestCase {

    func test_check_valid_emails_should_return_true() {
        let validEmails = [
            "example@Placeholder.com",
            "a@Placeholder.com",
            "example@Placeholder.cc"
        ]

        validEmails.forEach { validEmail in
            XCTAssertTrue(FieldValidator.check(.email(validEmail)))
        }
    }

    func test_check_invalid_emails_should_return_false() {
        let invalidEmails = [
            "Placeholder@.com",
            "@Placeholder.com",
            "example@Placeholder",
            "example@Placeholder.c",
            "Placeholder@_.com"
        ]

        invalidEmails.forEach { invalidEmail in
            XCTAssertFalse(FieldValidator.check(.email(invalidEmail)))
        }
    }

    func test_check_password_with_valid_password_should_return_true() {
        let validPassword = "Placeholder-12345678"
        XCTAssertTrue(FieldValidator.check(.passwordNew(validPassword)))
    }

    func test_check_password_with_invalid_password_should_return_false() {
        let lessThanSixChars = "12345"
        XCTAssertFalse(FieldValidator.check(.passwordNew(lessThanSixChars)))
    }

    func test_check_valid_repeat_password_should_return_true() {
        let originalPassword = "Placeholder1234"
        let repeatPassword = "Placeholder1234"

        XCTAssertTrue(FieldValidator.checkRepeatPassword(
            originalPassword, originalPassword: repeatPassword
        ))
    }

    func test_check_invalid_repeat_password_should_return_true() {
        let originalPassword = "Placeholder1234"
        let repeatPassword = "Placeholder1"

        XCTAssertFalse(FieldValidator.checkRepeatPassword(
            originalPassword, originalPassword: repeatPassword
        ))
    }

    func test_check_valid_otp_should_return_true() {
        let validOtp = "123456"
        XCTAssertTrue(FieldValidator.check(.otp(validOtp)))
    }

    func test_check_invalid_otp_should_return_false() {
        let invalidOtp = "1"
        XCTAssertFalse(FieldValidator.check(.otp(invalidOtp)))
    }

    func test_check_greater_otp_should_return_false() {
        let invalidOtp = "1234567"
        XCTAssertFalse(FieldValidator.check(.otp(invalidOtp)))
    }

    func test_check_otp_with_letters_should_return_false() {
        let invalidOtp = "A23456"
        XCTAssertFalse(FieldValidator.check(.otp(invalidOtp)))
    }
}
