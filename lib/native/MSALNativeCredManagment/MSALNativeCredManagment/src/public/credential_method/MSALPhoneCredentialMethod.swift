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

/// Represents a phone number credential method (SMS or voice call OTP).
@objcMembers
public class MSALPhoneCredentialMethod: MSALCredentialMethod {

    /// The masked phone number (e.g., "+1 ***-***-1234").
    public let phoneNumber: String?

    /// The phone type — "mobile" or "office".
    public let phoneType: String?

    /// The delivery channel — "sms" or "voice".
    public let smsSignInState: String?

    public init(
        id: String,
        isDefault: Bool,
        createdAt: Date?,
        phoneNumber: String?,
        phoneType: String? = "mobile",
        smsSignInState: String? = nil
    )
    {
        self.phoneNumber = phoneNumber
        self.phoneType = phoneType
        self.smsSignInState = smsSignInState
        super.init(
            id: id,
            credentialType: "phone",
            displayName: phoneNumber,
            isDefault: isDefault,
            createdAt: createdAt
        )
    }
}
