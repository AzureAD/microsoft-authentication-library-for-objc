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


import XCTest
@testable import MSAL
@_implementationOnly import MSAL_E2E_Test_Private
import MSIDAutomation

class MSALNativeAuthEndToEndPasswordTestCase: MSALNativeAuthEndToEndBaseTestCase {
    
    private class PasswordConstants {
        static let certificatePasswordKey = "certificate_password"
        static let certificateContentKey = "certificate_data"
    }
    
    private static var keyVaultAuthentication: KeyvaultAuthentication? = nil
    
    override class func setUp() {
        super.setUp()
        
        guard let certificatePassword = confFileContent?[PasswordConstants.certificatePasswordKey] as? String, let certificateContent = confFileContent?[PasswordConstants.certificateContentKey] as? String else {
            XCTFail("Can't parse certificate password or data")
            return
        }
        keyVaultAuthentication = KeyvaultAuthentication(certContents: certificateContent, certPassword: certificatePassword)
    }
    
    func retrievePasswordForSignInUsername() async -> String? {
        // TODO: find correct url and move in conf.json
        let url = URL(string: "KeyvaultString here")!
        return await withCheckedContinuation { continuation in
            Secret.get(url) { result in
                switch result {
                case .Success(let secret):
                    print(secret)
                    continuation.resume(returning: secret.value)
                case .Failure(let error):
                    print(error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
}
