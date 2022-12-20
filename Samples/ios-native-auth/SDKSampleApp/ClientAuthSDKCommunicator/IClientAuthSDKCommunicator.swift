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

protocol IClientAuthSDKCommunicator {

    func signUp(
        emailOrNumber: String, password: String, userClaims: [String: String],
        callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void)

    func verify(referenceId: String, otp: String, callback: @escaping (Bool, Error?) -> Void)

    func startPasswordless(
        email: String, callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void)

    func signIn(
        emailOrNumber: String, password: String, scope: [String],
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void)

    func signIn(
        email: String, otp: String, scope: [String], referenceId: String,
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void)

    func startResetPassword(
        email: String, callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void)

    func resetPassword(
        email: String, password: String, referenceId: String,
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void)

    func signOut(callback: @escaping (Bool, Error?) -> Void)
}
