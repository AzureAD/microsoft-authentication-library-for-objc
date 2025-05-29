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

@_implementationOnly import MSAL_Private

struct MSALNativeAuthInternalConfiguration {
    var challengeTypesString: String {
        return challengeTypes.map { $0.rawValue }.joined(separator: " ")
    }
    
    var capabilitiesString: String? {
        return capabilities?.map { $0.rawValue }.joined(separator: " ")
    }

    let clientId: String
    let authority: MSIDCIAMAuthority
    let challengeTypes: [MSALNativeAuthInternalChallengeType]
    let capabilities: [MSALNativeAuthInternalCapability]?
    let redirectUri: String?
    var sliceConfig: MSALSliceConfig?

    init(
        clientId: String,
        authority: MSALCIAMAuthority,
        challengeTypes: MSALNativeAuthChallengeTypes,
        capabilities: MSALNativeAuthCapabilities?,
        redirectUri: String?) throws {
        self.clientId = clientId
        self.authority = try MSIDCIAMAuthority(
            url: authority.url,
            validateFormat: false,
            context: MSALNativeAuthRequestContext()
        )
        self.challengeTypes = MSALNativeAuthInternalConfiguration.getInternalChallengeTypes(challengeTypes)
        self.capabilities = MSALNativeAuthInternalConfiguration.getInternalCapabilities(capabilities)
        self.redirectUri = redirectUri
    }

    private static func getInternalChallengeTypes(
        _ challengeTypes: MSALNativeAuthChallengeTypes
    ) -> [MSALNativeAuthInternalChallengeType] {
        var internalChallengeTypes = [MSALNativeAuthInternalChallengeType]()

        if challengeTypes.contains(.OOB) {
            internalChallengeTypes.append(.oob)
        }

        if challengeTypes.contains(.password) {
            internalChallengeTypes.append(.password)
        }

        internalChallengeTypes.append(.redirect)
        return internalChallengeTypes
    }
    
    private static func getInternalCapabilities(
        _ capabilities: MSALNativeAuthCapabilities?
    ) -> [MSALNativeAuthInternalCapability]? {
        guard let capabilities else { return nil }
        var internalCapabilities: [MSALNativeAuthInternalCapability] = []
        
        if capabilities.contains(.mfaRequired) {
            internalCapabilities.append(.mfaRequired)
        }
        
        if capabilities.contains(.registrationRequired) {
            internalCapabilities.append(.registrationRequired)
        }
        return internalCapabilities
    }
}
