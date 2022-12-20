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

import Foundation

final class FieldValidator {

    enum Field {
        case email(String?)
        case passwordNew(String?)
        case password(String?)
        case repeatPassword(String?)
        case otp(String?)
    }

    // MARK: - Public

    static func check(_ field: Field) -> Bool {
        switch field {
        case .email(let text):
            return validateEmail(text)
        case .passwordNew(let text), .password(let text), .repeatPassword(let text):
            return validatePassword(text)
        case .otp(let text):
            return validateOtp(text)
        }
    }

    static func checkRepeatPassword(_ password: String, originalPassword: String) -> Bool {
        password == originalPassword
    }

    // MARK: - Private methods

    private static func validateEmail(_ email: String?) -> Bool {
        guard let email = email else { return false }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private static func validatePassword(_ password: String?) -> Bool {
        guard let password = password else { return false }

        return password.count >= 6 && password.count <= 64
    }

    private static func validateOtp(_ code: String?) -> Bool {
        guard let code = code else { return false }

        let otpRegex = "^(\\d{6})$"
        return code.range(of: otpRegex, options: .regularExpression) != nil
    }
}
