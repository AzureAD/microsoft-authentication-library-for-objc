// ------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------

/// Work/school account-registration input supplied as decoded QR text or an activation code and URL.
/// Initializers preserve the supplied values; interpreting and validating registration data belongs to the SDK.
public final class MSALNativeAuthMFARegistrationParameters: Sendable {
    /// Decoded QR text, or nil for manually entered details. Do not log this value.
    public let qrCode: String?

    /// Manually entered activation code. Do not log this value.
    public let activationCode: String?

    /// Manually entered activation URL. Do not log this value.
    public let activationURL: String?

    /// Creates activation parameters without requiring account sign-in.
    /// Supply the push destination separately through the manager's `updatePushRegistration` operation.
    public init(qrCode: String) {
        self.qrCode = qrCode
        self.activationCode = nil
        self.activationURL = nil
    }

    /// Creates the same activation input as a QR code without requiring a camera.
    /// The URL is the activation URL provided by the enrollment page, not an authority or tenant URL.
    public init(activationCode: String, activationURL: String) {
        self.qrCode = nil
        self.activationCode = activationCode
        self.activationURL = activationURL
    }

    internal func validatedActivation() throws -> MSALNativeAuthMFAActivation {
        if let qrCode {
            return try MSALNativeAuthMFAActivation(qrCode: qrCode)
        }
        guard let activationCode, let activationURL else {
            throw MSALNativeAuthMFAServiceError.invalidActivationInput
        }
        return try MSALNativeAuthMFAActivation(code: activationCode, url: activationURL)
    }
}
