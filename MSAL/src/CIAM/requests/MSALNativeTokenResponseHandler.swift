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
    var accountIdentifier: MSIDAccountIdentifier { get }
    var context: MSIDRequestContext { get }
    var configuration: MSIDConfiguration { get }

    func handle(tokenResponse: MSIDTokenResponse, validateAccount: Bool) throws -> MSIDTokenResult
}

final class MSALNativeTokenResponseHandler: MSALNativeTokenResponseHandling {

    // MARK: - Variables

    let tokenResponseValidator: MSALNativeTokenResponseValidating
    let accountIdentifier: MSIDAccountIdentifier
    let context: MSIDRequestContext
    let configuration: MSIDConfiguration

    // MARK: - Init

    init(
        tokenResponseValidator: MSALNativeTokenResponseValidating,
        accountIdentifier: MSIDAccountIdentifier,
        context: MSIDRequestContext,
        configuration: MSIDConfiguration
    ) {
        self.tokenResponseValidator = tokenResponseValidator
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
            accountIdentifier: accountIdentifier,
            context: context,
            configuration: configuration
        )
    }

    // MARK: - Internal

    func handle(tokenResponse: MSIDTokenResponse, validateAccount: Bool) throws -> MSIDTokenResult {
        MSALLogger.log(level: .info, context: context, format: "Validate and save token response...")

        let tokenResult = try tokenResponseValidator.validateResponse(tokenResponse)

        if validateAccount {
            performAccountValidation(tokenResult)
        }

        return tokenResult
    }

    private func performAccountValidation(_ tokenResult: MSIDTokenResult) {
        var error: NSError?

        let accountChecked = tokenResponseValidator.validateAccount(with: tokenResult, error: &error)

        MSALLogger.logPII(
            level: error == nil ? .info : .error,
            context: context,
            format: "Validated account with result %d, old account %@, new account %@",
            accountChecked,
            MSALLogMask.maskTrackablePII(accountIdentifier.uid),
            MSALLogMask.maskTrackablePII(tokenResult.account.accountIdentifier.uid)
        )
    }
}
