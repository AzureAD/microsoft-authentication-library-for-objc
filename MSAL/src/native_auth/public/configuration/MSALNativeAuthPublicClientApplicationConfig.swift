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

@objcMembers
public final class MSALNativeAuthPublicClientApplicationConfig: MSALPublicClientApplicationConfig {

    let challengeTypes: MSALNativeAuthChallengeTypes

    /** The set of capabilities that this application can support as an ``MSALNativeAuthCapabilities`` optionset */
    public var capabilities: MSALNativeAuthCapabilities = []

    /// Initialize a MSALNativeAuthPublicClientApplicationConfig.
    /// - Parameters:
    ///   - clientId: The client ID of the application, this should come from the app developer portal.
    ///   - authority: The target authority.
    ///   - challengeTypes: The set of challenge types that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    public init(clientId: String, authority: MSALAuthority, challengeTypes: MSALNativeAuthChallengeTypes) {
        self.challengeTypes = challengeTypes
        // calling the init without nestedAuthBrokerClientId and nestedAuthBrokerRedirectUri result in an error
        super.init(clientId: clientId, redirectUri: nil, authority: authority, nestedAuthBrokerClientId: nil, nestedAuthBrokerRedirectUri: nil)
    }

    /// Initialize a MSALNativeAuthPublicClientApplicationConfig.
    /// - Parameters:
    ///   - clientId: The client ID of the application, this should come from the app developer portal.
    ///   - tenantSubdomain: The subdomain of the tenant, this should come from the app developer portal.
    ///   - challengeTypes: The set of challenge types that this application can support as an ``MSALNativeAuthChallengeTypes`` optionset
    /// - Throws: An error that occurred creating the application object
    public init(clientId: String, tenantSubdomain: String, challengeTypes: MSALNativeAuthChallengeTypes) throws {
        self.challengeTypes = challengeTypes
        let ciamAuthority = try MSALNativeAuthAuthorityProvider().authority(rawTenant: tenantSubdomain)
        // calling the init without nestedAuthBrokerClientId and nestedAuthBrokerRedirectUri result in an error
        super.init(clientId: clientId, redirectUri: nil, authority: ciamAuthority, nestedAuthBrokerClientId: nil, nestedAuthBrokerRedirectUri: nil)
    }

    static internal func convertChallengeTypes(
        _ internalChallengeTypes: [MSALNativeAuthInternalChallengeType]
    ) -> MSALNativeAuthChallengeTypes {
        var challenges: MSALNativeAuthChallengeTypes = []
        for challenge in internalChallengeTypes {
            switch challenge {
            case .oob:
                challenges.insert(.OOB)
            case .password:
                challenges.insert(.password)
            default:
                break
            }
        }
        return challenges
    }

    static internal func convertCapabilities(
        _ internalCapabilities: [MSALNativeAuthInternalCapability]?
    ) -> MSALNativeAuthCapabilities? {
        guard let internalCapabilities else {
            return nil
        }
        var capabilities: MSALNativeAuthCapabilities = []
        for capability in internalCapabilities {
            switch capability {
            case .mfaRequired:
                capabilities.insert(.mfaRequired)
            case .registrationRequired:
                capabilities.insert(.registrationRequired)
            }
        }
        return capabilities
    }
}
