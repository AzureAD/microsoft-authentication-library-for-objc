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

import Foundation
@_implementationOnly import MSAL_Private

final class MSALNativeAuthCredentialsController: MSALNativeAuthTokenController, MSALNativeAuthCredentialsControlling {

    // MARK: - Variables

    private let cacheAccessor: MSALNativeAuthCacheInterface

    // MARK: - Init

    override init(
        clientId: String,
        requestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        responseValidator: MSALNativeAuthTokenResponseValidating
    ) {
        self.cacheAccessor = cacheAccessor
        super.init(
            clientId: clientId,
            requestProvider: requestProvider,
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: responseValidator
        )
    }

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        let factory = MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: MSALNativeAuthTokenResponseValidator(factory: factory,
                                                                    msidValidator: MSIDTokenResponseValidator())
        )
    }

    // MARK: Internal

    func retrieveUserAccountResult(context: MSALNativeAuthRequestContext) -> MSALNativeAuthUserAccountResult? {
        let accounts = self.allAccounts()
        if let account = accounts.first {
            // We pass an empty array of scopes because that will return all tokens for that account identifier
            guard let rawIdToken = retrieveIdToken(account: account,
                                                   scopes: [],
                                                   context: context) else {
                MSALLogger.log(level: .verbose, context: context, format: "No Id token found")
                return nil
            }
            return factory.makeUserAccountResult(account: account, rawIdToken: rawIdToken)
        } else {
            MSALLogger.log(level: .verbose, context: nil, format: "No account found")
        }
        return nil
    }

    // MARK: - Private

    private func allAccounts() -> [MSALAccount] {
        do {
            // We pass an empty array of scopes because that will return all accounts
            // that have been saved for the current Client Id. We expect only one account to exist at this point per Client Id
            let config = factory.makeMSIDConfiguration(scopes: [])
            return try cacheAccessor.getAllAccounts(configuration: config)
        } catch {
            MSALLogger.logPII(
                level: .error,
                context: nil,
                format: "Error retrieving accounts \(MSALLogMask.maskPII(error))")
        }
        return []
    }

    private func retrieveIdToken(
        account: MSALAccount,
        scopes: [String],
        context: MSALNativeAuthRequestContext
    ) -> String? {
        do {
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            return try cacheAccessor.getIdToken(account: account, configuration: config, context: context)
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Error retrieving IdToken"
            )
        }
        return nil
    }
}
