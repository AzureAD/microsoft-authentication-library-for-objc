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

@_implementationOnly import MSAL_Private

protocol MSALNativeTokenResponseHandling {

    var tokenResponseValidator: MSALNativeTokenResponseValidating { get }
    var tokenCache: MSALNativeAuthCacheInterface { get }
    var accountIdentifier: MSIDAccountIdentifier { get }
    var context: MSIDRequestContext { get }
    var configuration: MSIDConfiguration { get }

    func handle(tokenResponse: MSIDTokenResponse, validateAccount: Bool) throws -> MSIDTokenResult
}

class MSALNativeTokenResponseHandler: MSALNativeTokenResponseHandling {

    // MARK: - Variables

    let tokenResponseValidator: MSALNativeTokenResponseValidating
    let tokenCache: MSALNativeAuthCacheInterface
    let accountIdentifier: MSIDAccountIdentifier
    let context: MSIDRequestContext
    let configuration: MSIDConfiguration

    // MARK: - Init

    init(
        tokenResponseValidator: MSALNativeTokenResponseValidating,
        tokenCache: MSALNativeAuthCacheInterface,
        accountIdentifier: MSIDAccountIdentifier,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration
    ) {
        self.tokenResponseValidator = tokenResponseValidator
        self.tokenCache = tokenCache
        self.accountIdentifier = accountIdentifier
        self.context = context
        self.configuration = configuration
    }

    convenience init(
        accountIdentifier: MSIDAccountIdentifier,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration
    ) {
        let tokenResponseValidator = MSALNativeTokenResponseValidator(
            factory: MSIDAADOauth2Factory(),
            context: context,
            configuration: configuration,
            accountIdentifier: accountIdentifier
        )

        self.init(
            tokenResponseValidator: tokenResponseValidator,
            tokenCache: MSALNativeAuthCacheGateway(),
            accountIdentifier: accountIdentifier,
            context: context,
            configuration: configuration
        )
    }

    // MARK: - Public

    func handle(tokenResponse: MSIDTokenResponse, validateAccount: Bool) throws -> MSIDTokenResult {
        MSALLogger.log(level: .info, context: context, format: "Validate and save token response...")

        do {
            let tokenResult = try tokenResponseValidator.validateResponse(tokenResponse)

            if validateAccount {
                performAccountValidation(tokenResult)
            }

            try tokenCache.saveTokensAndAccount(
                tokenResult: tokenResponse,
                configuration: configuration,
                context: context
            )

            return tokenResult

        } catch MSALNativeError.serverProtectionPoliciesRequired(let homeAccountId) {
            MSALLogger.log(level: .info, context: context, format: "Received Protection Policy Required error.")
            throw MSALNativeError.serverProtectionPoliciesRequired(homeAccountId: homeAccountId)
        } catch {
            throw MSALNativeError.validationError
        }
    }

    private func performAccountValidation(_ tokenResult: MSIDTokenResult) {
        let accountChecked = tokenResponseValidator.validateAccount(with: tokenResult)

        MSALLogger.logPII(
            level: .info,
            context: context,
            format: "Validated result account with result %d, old account %@, new account %@",
            accountChecked,
            MSALLogMask.maskTrackablePII(accountIdentifier.uid),
            MSALLogMask.maskTrackablePII(tokenResult.account.accountIdentifier.uid)
        )
    }
}
