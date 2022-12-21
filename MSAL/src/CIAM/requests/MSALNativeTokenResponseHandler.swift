//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

import Foundation
@_implementationOnly import MSAL_Private

protocol MSALNativeTokenResponseHandling {

    var tokenResponseValidator: MSIDTokenResponseValidator { get }
    var factory: MSIDAADOauth2Factory { get }
    var tokenCache: MSALNativeAuthCacheInterface { get }
    var accountIdentifier: MSIDAccountIdentifier { get }
    var context: MSIDRequestContext { get }
    var configuration: MSIDConfiguration { get }

    func handle(tokenResponse: MSIDTokenResponse, homeAccountId: String?, validateAccount: Bool) throws -> MSIDTokenResult
}

class MSALNativeTokenResponseHandler: MSALNativeTokenResponseHandling {

    // MARK: - Variables

    let tokenResponseValidator: MSIDTokenResponseValidator
    let factory: MSIDAADOauth2Factory
    let tokenCache: MSALNativeAuthCacheInterface
    let accountIdentifier: MSIDAccountIdentifier
    let context: MSIDRequestContext
    let configuration: MSIDConfiguration

    // MARK: - Init

    init(
        tokenResponseValidator: MSIDTokenResponseValidator,
        factory: MSIDAADOauth2Factory,
        tokenCache: MSALNativeAuthCacheInterface,
        accountIdentifier: MSIDAccountIdentifier,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration
    ) {
        self.tokenResponseValidator = tokenResponseValidator
        self.factory = factory
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
        self.init(
            tokenResponseValidator: MSIDTokenResponseValidator(),
            factory: MSIDAADOauth2Factory(),
            tokenCache: MSALNativeAuthCacheGateway(),
            accountIdentifier: accountIdentifier,
            context: context,
            configuration: configuration
        )
    }

    // MARK: - Public

    func handle(
        tokenResponse: MSIDTokenResponse,
        homeAccountId: String? = nil,
        validateAccount: Bool
    ) throws -> MSIDTokenResult {
        MSALLogger.log(level: .info, context: context, format: "Validate and save token response...")

        var validationError: NSError?

        guard let tokenResult = tokenResponseValidator.validate(
            tokenResponse,
            oauthFactory: factory,
            configuration: configuration,
            requestAccount: accountIdentifier,
            correlationID: context.correlationId(),
            error: &validationError
        ) else {
            throw MSALNativeError.validationError
        }

        // Special case - need to return homeAccountId in case of Intune policies required.

        try checkIntunePoliciesRequired(error: validationError, homeAccountId: homeAccountId)

        if validateAccount {
            performAccountValidation(tokenResult)
        }

        try tokenCache.saveTokensAndAccount(
            tokenResult: tokenResponse,
            configuration: configuration,
            context: context
        )

        return tokenResult
    }

    private func checkIntunePoliciesRequired(error: NSError?, homeAccountId: String?) throws {
        if var error = error, error.code == MSIDErrorCode.serverProtectionPoliciesRequired.rawValue {

            MSALLogger.log(level: .info, context: context, format: "Received Protection Policy Required error.")
            var updatedUserInfo = error.userInfo

            if let homeAccountId = homeAccountId {
                updatedUserInfo[MSIDHomeAccountIdkey] = homeAccountId
            }

            error = MSIDCreateError(
                error.domain,
                error.code,
                nil, nil, nil, nil, nil,
                updatedUserInfo,
                true
            ) as NSError

            throw error
        }
    }

    private func performAccountValidation(_ tokenResult: MSIDTokenResult) {
        var tokenResponseValidatorError: NSError?

        let accountChecked = tokenResponseValidator.validateAccount(
            accountIdentifier,
            tokenResult: tokenResult,
            correlationID: context.correlationId(),
            error: &tokenResponseValidatorError
        )

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
