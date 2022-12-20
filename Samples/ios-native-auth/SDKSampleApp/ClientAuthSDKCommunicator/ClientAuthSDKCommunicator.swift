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

import AuthenticationServices
import Foundation

extension String: Error {}

class ClientAuthSDKCommunicator: NSObject, IClientAuthSDKCommunicator {

    private var referenceIds = Set<String>()
    private var userPool = [String: String?]()

    func signUp(
        emailOrNumber: String, password: String, userClaims: [String: String],
        callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void
    ) {
        callback(nil, nil)
    }

    func signIn(
        emailOrNumber: String, password: String, scope: [String],
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void
    ) {
        callback(nil, nil)
    }

    func verify(referenceId: String, otp: String, callback: @escaping (Bool, Error?) -> Void) {
        callback(false, nil)
    }

    func signOut(callback: @escaping (Bool, Error?) -> Void) {
        callback(false, nil)
    }

    // MARK: mocked implementations

    func startPasswordless(
        email: String, callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void
    ) {
        let key = email.lowercased()
        let referenceId = generateReferenceId()

        if !userPool.keys.contains(key) {
            userPool.updateValue(nil, forKey: key)
            referenceIds.insert(referenceId)
            callback(referenceId, nil)
        } else if userPool.hasNilValue(for: key) {
            referenceIds.insert(referenceId)
            callback(referenceId, nil)
        } else {
            callback(nil, "Email already in use")
        }
    }

    func signIn(
        email: String, otp: String, scope: [String], referenceId: String,
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void
    ) {
        let key = email.lowercased()

        guard userPool.hasNilValue(for: key) else {
            callback(nil, "Email already in use")
            return
        }

        guard referenceId.contains(referenceId) else {
            callback(nil, "Reference ID not found")
            return
        }

        referenceIds.remove(referenceId)
        callback(generateAccessToken(), nil)
    }

    func startResetPassword(
        email: String, callback: @escaping (_ referenceId: String?, _ error: Error?) -> Void
    ) {
        let key = email.lowercased()

        guard userPool.keys.contains(key) else {
            callback(nil, "Email not found")
            return
        }

        guard !userPool.hasNilValue(for: key) else {
            callback(nil, "Not allowed to change password")
            return
        }

        let referenceId = generateReferenceId()

        referenceIds.insert(referenceId)
        callback(referenceId, nil)
    }

    func resetPassword(
        email: String, password: String, referenceId: String,
        callback: @escaping (_ accessToken: String?, _ error: Error?) -> Void
    ) {
        guard !userPool.hasNilValue(for: email) else {
            callback(nil, "User does not exist")
            return
        }

        userPool[email] = password

        callback(generateAccessToken(), nil)
    }

    // MARK: private methods

    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    private func generateAccessToken() -> String {
        randomString(length: 255)
    }

    private func generateReferenceId() -> String {
        randomString(length: 20)
    }
}

extension Dictionary where Value == String? {
    fileprivate func hasNilValue(for key: Key) -> Bool {
        self[key] == Optional(Optional(nil))
    }
}
