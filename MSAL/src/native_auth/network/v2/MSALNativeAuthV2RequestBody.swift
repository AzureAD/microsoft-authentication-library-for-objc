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

/// Typed body of a Native Auth V2 (HAL) follow-up request. Each field maps to a
/// ``MSALNativeAuthV2RequestBodyKey`` and is emitted only when set, so a caller states just the
/// fields the operation carries
struct MSALNativeAuthV2RequestBody {
    let continuationToken: String
    var otp: String?
    var newPassword: String?

    var dictionary: [String: Any] {
        var body: [String: Any] = [MSALNativeAuthV2RequestBodyKey.continuationToken.rawValue: continuationToken]

        if let otp = otp {
            body[MSALNativeAuthV2RequestBodyKey.otp.rawValue] = otp
        }
        if let newPassword = newPassword {
            body[MSALNativeAuthV2RequestBodyKey.newPassword.rawValue] = newPassword
        }

        return body
    }
}
