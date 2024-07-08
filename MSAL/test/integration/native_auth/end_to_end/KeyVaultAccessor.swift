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

class KeyVaultAccessor: XCTestCase {
    
/*    MSIDClientCredentialHelper.getAccessToken(forAuthority: authority, resource: resource, clientId: self.clientId, certificate: self.certificateData, certificatePassword: self.certificatePassword, completionHandler: { (optionalAccessToken, error) in*/
    
    override func setUp() async throws {
//        Authentication.authCallback = { (authority, resource, callback) in
//
//            MSIDClientCredentialHelper.getAccessToken(forAuthority: authority, resource: resource, clientId: self.clientId, certificate: self.certificateData, certificatePassword: self.certificatePassword, completionHandler: { (optionalAccessToken, error) in
//
//                guard let accessToken = optionalAccessToken else {
//                    print("Got an error, can't continue \(String(describing: error))")
//                    callback(.Failure(error!))
//                    return
//                }
//
//                print("Successfully received an access token, returning the keyvault callback")
//
//                DispatchQueue.global().async {
//                    callback(.Success(accessToken))
//                }
//            })
        
        KeyvaultAuthentication(certContents: <#T##String#>, certPassword: <#T##String#>)
    }
    
    func testRetrieveSomething() async {
//        MSIDClientCredentialHelper.getAccessToken(forAuthority: "", resource: "", clientId: "", certificate: Data(), certificatePassword: "") { someString, error in
//            
//        }
        
        let expectation = expectation(description: "test")
        let passHandler = MSIDAutomationPasswordRequestHandler()
        let account = MSIDTestAutomationAccount()
        account.keyvaultName = "https://msidlabs.vault.azure.net:443/secrets/LabResetCode"
        passHandler.loadPassword(forTest: account) { secret, error in
            XCTAssertNil(error)
            XCTAssertNotNil(secret)
            print(secret)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    }
