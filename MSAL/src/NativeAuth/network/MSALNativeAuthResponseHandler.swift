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

protocol MSALNativeAuthResponseHandling {

    var tokenResponseValidator: MSALNativeAuthTokenResponseValidating { get }

    func handle(
        context: MSIDRequestContext,
        accountIdentifier: MSIDAccountIdentifier,
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        validateAccount: Bool) throws -> MSIDTokenResult
}

final class MSALNativeAuthResponseHandler: MSALNativeAuthResponseHandling {

    // MARK: - Variables

    let tokenResponseValidator: MSALNativeAuthTokenResponseValidating

    // MARK: - Init

    init(tokenResponseValidator: MSALNativeAuthTokenResponseValidating) {
        self.tokenResponseValidator = tokenResponseValidator
    }

    convenience init() {
        let tokenResponseValidator = MSALNativeAuthTokenResponseValidator(
            factory: MSIDAADOauth2Factory())
        self.init(tokenResponseValidator: tokenResponseValidator)
    }

    // MARK: - Internal

    func handle(context: MSIDRequestContext,
                accountIdentifier: MSIDAccountIdentifier,
                tokenResponse: MSIDTokenResponse,
                configuration: MSIDConfiguration,
                validateAccount: Bool) throws -> MSIDTokenResult {
        MSALLogger.log(level: .info, context: context, format: "Validate and save token response...")

        let tokenResult = try tokenResponseValidator.validateResponse(tokenResponse: tokenResponse,
                                                                      context: context,
                                                                      configuration: configuration,
                                                                      accountIdentifier: accountIdentifier)

        if validateAccount {
            performAccountValidation(
                tokenResult: tokenResult,
                context: context,
                accountIdentifier: accountIdentifier,
                configuration: configuration)
        }

        return tokenResult
    }

    private func performAccountValidation(
        tokenResult: MSIDTokenResult,
        context: MSIDRequestContext,
        accountIdentifier: MSIDAccountIdentifier,
        configuration: MSIDConfiguration) {
        var error: NSError?
        let accountChecked = tokenResponseValidator.validateAccount(with: tokenResult,
                                                                    context: context,
                                                                    configuration: configuration,
                                                                    accountIdentifier: accountIdentifier,
                                                                    error: &error)

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
