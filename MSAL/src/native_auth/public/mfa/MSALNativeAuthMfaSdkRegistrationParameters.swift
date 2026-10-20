//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

/// Account-registration input supplied either as decoded QR text or manually entered account details.
/// Initializers preserve the supplied values; interpreting and validating registration data belongs to the SDK.
public final class MSALNativeAuthMfaSdkRegistrationParameters: Sendable {
    /// Decoded QR text, or nil for manually entered details. Do not log this value.
    public let qrCode: String?

    /// Manually entered account name, or nil for QR input.
    public let accountName: String?

    /// Manually entered secret key, or nil for QR input. Do not log this value.
    public let secretKey: String?

    /// Creates activation parameters without requiring account sign-in.
    /// Supply the push destination separately through the manager's `updatePushRegistration` operation.
    public init(qrCode: String) {
        self.qrCode = qrCode
        self.accountName = nil
        self.secretKey = nil
    }

    /// Creates registration parameters directly from entered details, without constructing a QR payload.
    public init(accountName: String, secretKey: String) {
        self.qrCode = nil
        self.accountName = accountName
        self.secretKey = secretKey
    }
}
