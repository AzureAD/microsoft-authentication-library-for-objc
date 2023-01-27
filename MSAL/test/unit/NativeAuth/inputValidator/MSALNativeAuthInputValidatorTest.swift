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

final class MSALNativeAuthInputValidatorTest: XCTestCase {
    
    private let validator = MSALNativeAuthInputValidator()
    
    func testEmail_whenValidEmailIsUsed_resultShouldBeValid() {
        XCTAssertTrue(validator.isEmailValid("email@contoso.com"))
        XCTAssertTrue(validator.isEmailValid("t@e.st"))
        XCTAssertTrue(validator.isEmailValid("loremipsumdolorsitametconsecteturadipiscingelitseddoeiusmodtemporincididuntutlaboreetdoloremagnaaliqua@e.st"))
        XCTAssertTrue(validator.isEmailValid("--@contoso.com"))
        XCTAssertTrue(validator.isEmailValid("firstname.lastname@microsoft.com"))
        XCTAssertTrue(validator.isEmailValid("email@microsoft.co.uk"))
        XCTAssertTrue(validator.isEmailValid("email@microsoft.museum"))
        XCTAssertTrue(validator.isEmailValid("firstname-lastname@microsoft.com"))
        XCTAssertTrue(validator.isEmailValid("email@microsoft-one.com"))
        XCTAssertTrue(validator.isEmailValid("1234567890@microsoft.com"))
        XCTAssertTrue(validator.isEmailValid("firstname+lastname@microsoft.com"))
        XCTAssertTrue(validator.isEmailValid("email@microsoft.contoso.com"))
        XCTAssertTrue(validator.isEmailValid("email@123.com"))
        XCTAssertTrue(validator.isEmailValid("_______@contoso.com"))
    }
    
    func testEmail_whenInvalidEmailIsUsed_resultShouldBeInvalid() {
        XCTAssertFalse(validator.isEmailValid("email@.com"))
        XCTAssertFalse(validator.isEmailValid("t@e"))
        XCTAssertFalse(validator.isEmailValid("example@micorosoft.loremipsumdolorsitametconsecteturadipiscingelitseddoeiusmodtemporincididuntutlaboreetdol"))
        XCTAssertFalse(validator.isEmailValid("contoso.com"))
        XCTAssertFalse(validator.isEmailValid("firstname.lastname@microsoft!.com"))
        XCTAssertFalse(validator.isEmailValid("email@contoso@microsoft.com"))
        XCTAssertFalse(validator.isEmailValid("email.contoso.com"))
        XCTAssertFalse(validator.isEmailValid("#@%^%#$@#$@#.com"))
        XCTAssertFalse(validator.isEmailValid("microsoft"))
        XCTAssertFalse(validator.isEmailValid("abc.def@microsoft#contoso.com"))
        XCTAssertFalse(validator.isEmailValid("あいうえお@microsoft.com"))
        XCTAssertFalse(validator.isEmailValid("abc.def@contoso.c"))
        XCTAssertFalse(validator.isEmailValid("ema il@123.com"))
        XCTAssertFalse(validator.isEmailValid("email@111.222.333.44444"))
        XCTAssertFalse(validator.isEmailValid("abc#def@contoso.com"))
        XCTAssertFalse(validator.isEmailValid("email@contoso.com (Joe Smith)"))
        XCTAssertFalse(validator.isEmailValid("Joe Smith <email@contoso.com>"))
        XCTAssertFalse(validator.isEmailValid("@contoso.com"))
    }
}
