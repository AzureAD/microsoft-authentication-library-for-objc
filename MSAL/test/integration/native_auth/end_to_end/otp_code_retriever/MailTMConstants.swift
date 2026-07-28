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

/// Environment-independent constants for the mail.tm API (endpoints, headers, JSON keys, etc.).
enum MailTMConstants {

    static let baseURL = "https://api.mail.tm"

    /// Progressive delays (seconds) between OTP read attempts, giving the email time to arrive.
    static let progressiveDelays: [Double] = [10, 20, 30]

    static let signupAddressPrefix = "native-auth-signup-"
    static let signupDomain = "mail.tm"
    static let createInboxAddressPrefix = "test"

    enum Path {
        static let domains = "/domains"
        static let accounts = "/accounts"
        static let token = "/token"
        static let sources = "/sources/"      // append the message id
        static let messages = "/messages?page=1"
    }

    enum Header {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let applicationJSON = "application/json"
        /// Scheme prefix for the bearer Authorization header value.
        static let bearerPrefix = "Bearer "
    }

    enum JSONKey {
        static let hydraMember = "hydra:member"
        static let domain = "domain"
        static let token = "token"
        static let data = "data"
        static let address = "address"
        static let password = "password"
        static let id = "id"
        static let updatedAt = "updatedAt"
        static let createdAt = "createdAt"
    }

    enum Status {
        static let ok = 200
        static let created = 201
        static let unprocessableEntity = 422
    }

    enum OTPPattern {
        static let explicit = "Account verification code:\\s*([0-9]+)"
        static let fallback = "(?<![0-9])([0-9]{4,8})(?![0-9])"
    }
}
