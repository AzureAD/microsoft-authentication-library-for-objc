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

@_implementationOnly import MSAL_Private

// TODO: Update this when the caching module is implemented

protocol MSALNativeCacheAccessor {

//    func getMsalNativeTokens(for accountIdentifier: MSIDAccountIdentifier) -> MSALNativeTokenResult

    func getMsalNativeAccount(for accountIdentifier: MSIDAccountIdentifier) -> MSIDAccount

//    @discardableResult
//    func saveMsalNativeTokens(_ tokenResult: MSALNativeTokenResult, accountIdentifier: MSIDAccountIdentifier) -> Result<MSALNativeTokenResult, Error>

    @discardableResult
    func saveMsalNativeAccount(_ account: MSIDAccount) -> Result<MSIDAccount, Error>

//    @discardableResult
//    func removeMsalNativeTokens(for account: MSIDAccount) -> Result<MSALNativeTokenResult, Error>

    @discardableResult
    func removeMsalNativeAccount(_ account: MSIDAccount) -> Result<MSIDAccount, Error>

    @discardableResult
    func clearMsalNativeCache(account: MSIDAccount) -> Result<MSIDAccount, Error>
}

extension MSIDDefaultTokenCacheAccessor: MSALNativeCacheAccessor {

//    func getMsalNativeTokens(for accountIdentifier: MSIDAccountIdentifier) -> MSALNativeTokenResult {
//        .init()
//    }

    func getMsalNativeAccount(for accountIdentifier: MSIDAccountIdentifier) -> MSIDAccount {
        .init()
    }

//    @discardableResult
//    func saveMsalNativeTokens(_ tokenResult: MSALNativeTokenResult, accountIdentifier: MSIDAccountIdentifier) -> Result<MSALNativeTokenResult, Error> {
//        // Convert tokenResult to MSIDCredentialCacheItem and use accountCredentialCache to store it?
//        .success(tokenResult)
//    }

    @discardableResult
    func saveMsalNativeAccount(_ account: MSIDAccount) -> Result<MSIDAccount, Error> {
        .success(.init())
    }

//    @discardableResult
//    func removeMsalNativeTokens(for account: MSIDAccount) -> Result<MSALNativeTokenResult, Error> {
//        .success(getMsalNativeTokens(for: account.accountIdentifier))
//    }

    @discardableResult
    func removeMsalNativeAccount(_ account: MSIDAccount) -> Result<MSIDAccount, Error> {
        .success(account)
    }

    @discardableResult
    func clearMsalNativeCache(account: MSIDAccount) -> Result<MSIDAccount, Error> {
        .success(account)
    }
}
