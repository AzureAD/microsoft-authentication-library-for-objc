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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

import Foundation

@objc
public final class MSALNativePublicClientApplication: NSObject {

    /**
     Initializes a new application.

     - Parameters:
        - configuration: `MSALCiamPublicClientApplicationConfig` . CIAM's sdk configuration, which contains authority, tenant and clientId.
     */
    @objc
    public init(configuration: MSALNativePublicClientApplicationConfig) {

    }

    // MARK: - Async/Await

    public func signUp(email: String, password: String, attributes: [String: Any]? = nil, scopes: [String]? = nil) async -> AuthResult {
        .success(.init(stage: .completed, sessionToken: nil, authentication: nil))
    }

    public func signUp(email: String, attributes: [String: Any]? = nil, scopes: [String]? = nil) async -> AuthResult {
        .success(.init(stage: .completed, sessionToken: nil, authentication: nil))
    }

    public func signIn(email: String, password: String) async -> AuthResult {
        .success(.init(stage: .completed, sessionToken: nil, authentication: nil))
    }

    public func signIn(email: String) async -> AuthResult {
        .success(.init(stage: .completed, sessionToken: nil, authentication: nil))
    }

    public func verifyCode(sessionToken: String, otp: String) async -> AuthResult {
        .success(.init(stage: .completed, sessionToken: nil, authentication: nil))
    }

    public func resendCode(sessionToken: String) async -> ResendCodeResult {
        .success("<sessionToken>")
    }

    public func getUserAccount() async -> UserAccountResult {
        .success(.init(email: ""))
    }

    // MARK: - Closures

    @objc
    public func signUp(email: String, password: String, attributes: [String: Any]? = nil, scopes: [String]? = nil, completion: @escaping (_ response: MSALNativeAuthResponse?, _ error: Error?) -> Void) {

    }

    @objc
    public func signUp(email: String, attributes: [String: Any]? = nil, scopes: [String]? = nil, completion: @escaping (_ response: MSALNativeAuthResponse, _ error: Error) -> Void) {

    }

    @objc
    public func signIn(email: String, password: String, completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void) {

    }

    @objc
    public func signIn(email: String, completion: @escaping (MSALNativeAuthResponse, Error) -> Void) {

    }

    @objc
    public func verifyCode(sessionToken: String, otp: String, completion: @escaping (MSALNativeAuthResponse, Error) -> Void) {

    }

    @objc
    public func resendCode(sessionToken: String, completion: @escaping (_ sessionToken: String, Error) -> Void) {

    }

    @objc
    public func getUserAccount(completion: @escaping (MSALNativeUserAccount, Error) -> Void) {

    }
}
