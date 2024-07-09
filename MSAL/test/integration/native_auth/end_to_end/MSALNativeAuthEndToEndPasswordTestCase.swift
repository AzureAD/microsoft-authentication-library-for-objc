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
import MSIDAutomation

class MSALNativeAuthEndToEndPasswordTestCase: MSALNativeAuthEndToEndBaseTestCase {
    
    private class PasswordConstants {
        static let certificatePasswordKey = "certificate_password"
        static let certificateContentKey = "certificate_data"
        static let keyVaultKey = "keyvault_url"
    }
    
    private static var keyVaultAuthentication: KeyvaultAuthentication? = nil
    
    override class func setUp() {
        super.setUp()
        
        guard let certificatePassword = confFileContent?[PasswordConstants.certificatePasswordKey] as? String, let certificateContent = confFileContent?[PasswordConstants.certificateContentKey] as? String else {
            XCTFail("Can't parse certificate password or data from conf.json file")
            return
        }
        keyVaultAuthentication = KeyvaultAuthentication(certContents: certificateContent, certPassword: certificatePassword)
    }
    
    func retrievePasswordForSignInUsername() async -> String? {
        guard 
            let keyVaultURLString = MSALNativeAuthEndToEndBaseTestCase.nativeAuthConfFileContent?[PasswordConstants.keyVaultKey] as? String,
            let url = URL(string: keyVaultURLString)
        else {
            XCTFail("Key vault URL not found or invalid in conf.json")
            return nil
        }
        return await withCheckedContinuation { continuation in
            Secret.get(url) { result in
                switch result {
                case .Success(let secret):
                    continuation.resume(returning: secret.value)
                case .Failure(let error):
                    print("Something went wrong retrieving the secret from keyVault: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
}
