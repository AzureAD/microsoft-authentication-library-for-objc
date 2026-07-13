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

import Foundation

/// Token-response cache persistence.
final class MSALNativeAuthTokenCacher {

    private let cacheAccessor: MSALNativeAuthCacheInterface

    init(cacheAccessor: MSALNativeAuthCacheInterface) {
        self.cacheAccessor = cacheAccessor
    }

    func cache(
        _ tokenResponse: MSIDTokenResponse,
        context: MSIDRequestContext,
        msidConfiguration: MSIDConfiguration,
        validateAccount: (_ tokenResult: MSIDTokenResult, _ accountIdentifier: MSIDAccountIdentifier) throws -> Bool
    ) throws -> MSIDTokenResult {
        let displayableId = tokenResponse.idTokenObj?.username()
        let homeAccountId = tokenResponse.idTokenObj?.userId

        guard let accountIdentifier = MSIDAccountIdentifier(displayableId: displayableId, homeAccountId: homeAccountId) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating account identifier")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        // Remove any existing account for this configuration before saving the new tokens.
        clearExistingAccount(msidConfiguration: msidConfiguration, context: context)

        let savedResult: MSIDTokenResult?
        do {
            savedResult = try cacheAccessor.validateAndSaveTokensAndAccount(
                tokenResponse: tokenResponse,
                configuration: msidConfiguration,
                context: context
            )
        } catch {
            MSALNativeAuthLogger.logPII(
                level: .warning,
                context: context,
                format: "Error caching response: \(MSALLogMask.maskEUII(error)) (ignoring)")
            savedResult = nil
        }

        guard let result = savedResult else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error caching token response")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        guard try validateAccount(result, accountIdentifier) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error validating account")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        return result
    }

    private func clearExistingAccount(msidConfiguration: MSIDConfiguration, context: MSIDRequestContext) {
        do {
            let accounts = try cacheAccessor.getAllAccounts(configuration: msidConfiguration)
            if let account = accounts.first {
                if let identifier = MSIDAccountIdentifier(displayableId: account.username, homeAccountId: account.identifier) {
                    try cacheAccessor.clearCache(
                        accountIdentifier: identifier,
                        authority: msidConfiguration.authority,
                        clientId: msidConfiguration.clientId,
                        context: context)
                }
            } else {
                MSALNativeAuthLogger.log(
                    level: .warning,
                    context: context,
                    format: "Error creating MSIDAccountIdentifier out of MSALAccount (ignoring)")
            }
        } catch {
            MSALNativeAuthLogger.log(level: .warning, context: context, format: "Error clearing previous account (ignoring)")
        }
    }
}
