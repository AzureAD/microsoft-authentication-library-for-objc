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

import XCTest
import MSAL

class MSALNativeAuthEndToEndBaseTestCase: XCTestCase {
    private class Constants {
        static let nativeAuthKey = "native_auth"
        static let clientIdEmailPasswordKey = "email_password_client_id"
        static let clientIdEmailCodeKey = "email_code_client_id"
        static let clientIdEmailPasswordAttributesKey = "email_password_attributes_client_id"
        static let clientIdEmailCodeAttributesKey = "email_code_attributes_client_id"
        static let tenantSubdomainKey = "tenant_subdomain"
        static let signInEmailPasswordUsernameKey = "sign_in_email_password_username"
        static let signInEmailCodeUsernameKey = "sign_in_email_code_username"
        static let resetPasswordUsernameKey = "reset_password_username"
    }
    
    let correlationId = UUID()
    let defaultTimeout: TimeInterval = 20

    private var confFileContent: [String: String]? = nil
    private let codeRetriever = MSALNativeAuthEmailCodeRetriever()

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let confURL = Bundle(for: Self.self).url(forResource: "conf", withExtension: "json"), let configurationData = try? Data(contentsOf: confURL) else {
            XCTFail("conf.json file not found")
            return
        }
        let confFile = try JSONSerialization.jsonObject(with: configurationData, options: []) as? [String: Any]
        confFileContent = confFile?[Constants.nativeAuthKey] as? [String: String]
    }
    
    func initialisePublicClientApplication(
        clientIdType: ClientIdType = .password,
        challengeTypes: MSALNativeAuthChallengeTypes = [.OOB, .password]
    ) -> MSALNativeAuthPublicClientApplication? {
        let clientIdKey = getClientIdKey(type: clientIdType)
        guard let clientId = confFileContent?[clientIdKey] as? String, let tenantSubdomain = confFileContent?[Constants.tenantSubdomainKey] as? String else {
            XCTFail("ClientId or tenantSubdomain not found in conf.json")
            return nil
        }
        return try? MSALNativeAuthPublicClientApplication(clientId: clientId, tenantSubdomain: tenantSubdomain, challengeTypes: challengeTypes)
    }
    
    func generateSignUpRandomEmail() -> String {
        return codeRetriever.generateRandomEmailAddress()
    }
    
    func retrieveCodeFor(email: String) async -> String? {
        return await codeRetriever.retrieveEmailOTPCode(email: email)
    }
    
    func getSignInUsernamePassword() -> String? {
        return confFileContent?[Constants.signInEmailPasswordUsernameKey]
    }
    
    private func getClientIdKey(type: ClientIdType) -> String {
        switch type {
        case .password:
            return Constants.clientIdEmailPasswordKey
        case .passwordAndAttributes:
            return Constants.clientIdEmailPasswordAttributesKey
        case .code:
            return Constants.clientIdEmailCodeKey
        case .codeAndAttributes:
            return Constants.clientIdEmailCodeAttributesKey
        }
    }
}
