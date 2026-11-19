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

import Foundation

final class MSALNativeAuthEmailOTPUserPool {
    enum ConfigurationError: LocalizedError, Equatable {
        case missingOrEmptyValue(String)
        case duplicateValues

        var errorDescription: String? {
            switch self {
            case .missingOrEmptyValue(let key):
                return "Email OTP username configuration '\(key)' is missing or empty."
            case .duplicateValues:
                return "Email OTP username configuration contains duplicate values."
            }
        }
    }

    private let usernames: [String]
    private let lock = NSLock()
    private var nextIndex = 0

    init(usernames: [String]) {
        precondition(!usernames.isEmpty)
        self.usernames = usernames
    }

    static func make(configuration: [String: String], keys: [String]) throws -> MSALNativeAuthEmailOTPUserPool {
        var usernames = [String]()

        for key in keys {
            guard let value = configuration[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                throw ConfigurationError.missingOrEmptyValue(key)
            }

            usernames.append(value)
        }

        guard Set(usernames).count == usernames.count else {
            throw ConfigurationError.duplicateValues
        }

        return MSALNativeAuthEmailOTPUserPool(usernames: usernames)
    }

    func nextUsername() -> String {
        lock.lock()
        defer { lock.unlock() }

        let username = usernames[nextIndex]
        nextIndex = (nextIndex + 1) % usernames.count
        return username
    }
}

final class MSALNativeAuthEmailOTPUsernameProvider {
    private var username: String?

    func username(from userPool: MSALNativeAuthEmailOTPUserPool) -> String {
        if let username {
            return username
        }

        let username = userPool.nextUsername()
        self.username = username
        return username
    }
}
