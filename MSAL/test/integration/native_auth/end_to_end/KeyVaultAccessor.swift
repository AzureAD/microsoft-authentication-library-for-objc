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

    var keyvaultAuthentication: KeyvaultAuthentication? = nil
    
    override func setUp() async throws {
        keyvaultAuthentication = KeyvaultAuthentication(certContents: "certContentHere", certPassword: "certPasswordhere")
    }
    
    func testRetrieveSomething() async {
        let expectation = expectation(description: "test")
        let url = URL(string: "https://msidlabs.vault.azure.net:443/secrets/LabResetCode")!
        Secret.get(url) { result in
            switch result {
            case .Success(let secret):
                print(secret)
            case .Failure(let error):
                print(error)
                XCTFail("something went wrong \(error)")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 10.0)
    }
}
