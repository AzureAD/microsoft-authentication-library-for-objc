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
import MSAL_Private

@objc public extension MSALAccount {

    @objc convenience init(
        username: String?,
        homeAccountId: MSALAccountId?,
        environment: String?,
        tenantProfiles: [MSALTenantProfile]?
    ) {
        self.init()
        self.username = username
        self.environment = environment
        self.homeAccountId = homeAccountId
        identifier = homeAccountId?.identifier
        lookupAccountIdentifier = MSIDAccountIdentifier(displayableId: username, homeAccountId: homeAccountId?.identifier)

        addTenantProfiles(tenantProfiles)
    }

    @objc convenience init(
        MSIDAccount account: MSIDAccount?,
        createTenantProfile: Bool
    ) {
        var tenantProfiles: [AnyHashable]?
        if createTenantProfile {
            let allClaims = account?.idTokenClaims?.jsonDictionary()
            let tenantProfile = MSALTenantProfile(
                identifier: account!.localAccountId ?? "",
                tenantId: account!.realm ?? "",
                environment: account!.storageEnvironment ?? account!.environment,
                isHomeTenantProfile: account!.isHomeTenantAccount(),
                claims: allClaims)
            tenantProfiles = [tenantProfile]
        }

        let homeAccountId = MSALAccountId(
            accountIdentifier: account?.accountIdentifier?.homeAccountId,
            objectId: account?.accountIdentifier?.uid,
            tenantId: account?.accountIdentifier?.utid)

        self.init(
            username: account?.username,
            homeAccountId: homeAccountId,
            environment: account?.storageEnvironment ?? account?.environment,
            tenantProfiles: tenantProfiles as? [MSALTenantProfile])

        if let accountIsSSOAccount = account?.isSSOAccount {
            isSSOAccount = accountIsSSOAccount
        }
    }

    @objc convenience init(
        MSIDAccount account: MSIDAccount?,
        createTenantProfile: Bool,
        accountClaims: [AnyHashable : Any]?
    ) {
        self.init(MSIDAccount: account, createTenantProfile: createTenantProfile)
        if let isHomeTenantAccount = account?.isHomeTenantAccount(), isHomeTenantAccount == true {
            if let accountClaims {
                var tempAccountClaims = [String: Any]()
                for (key, value) in accountClaims {
                    if let tempKey = key as? String {
                        tempAccountClaims[tempKey] = value
                    }
                }
                self.accountClaims = tempAccountClaims
            }

        }
    }

    @objc convenience init(
        MSALExternalAccount externalAccount: MSALAccount?,
        oauth2Provider oauthProvider: MSALOauth2Provider?
    ) {
        if let accountIdentifier = MSIDAccountIdentifier(displayableId: nil, homeAccountId: externalAccount?.identifier) {
            if let homeAccountId = MSALAccountId(
                accountIdentifier: accountIdentifier.homeAccountId,
                objectId: accountIdentifier.uid,
                tenantId: accountIdentifier.utid) {
                if let newAccountClaims = externalAccount!.accountClaims {
                    let anyHashableKeyedDict: [AnyHashable: Any] = Dictionary(uniqueKeysWithValues: newAccountClaims.map { key, value in (key as AnyHashable, value) })

                    if let currentExternalAccount = externalAccount {
                        do  {

                            let tenantProfile = try  oauthProvider?.tenantProfile(
                                withClaims: anyHashableKeyedDict,
                                homeAccountId: homeAccountId,
                                environment: currentExternalAccount.environment!)
                            if let tenantProfile {
                                let tenantProfiles = [tenantProfile]
                                self.init(
                                    username: externalAccount?.username,
                                    homeAccountId: homeAccountId,
                                    environment: externalAccount?.environment,
                                    tenantProfiles: tenantProfiles)
                            } else {
                                self.init()
                            }
                        } catch {
                            self.init()
                            print (error)
                            //MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, "Failed to create tenant profile with error code %ld, domain %@", (tenantProfileError as NSError).code, (tenantProfileError as NSError).domain)
                        }
                    } else {
                        self.init()
                    }
                } else {
                    self.init()
                }
            } else {
                self.init()
            }
        } else {
            self.init()
        }
    }

    func copy(with zone: NSZone? = nil) -> MSALAccount {
        let account = MSALAccount(username: username, homeAccountId: homeAccountId, environment: environment, tenantProfiles: tenantProfiles())
        account.accountClaims = accountClaims
        return account
    }

}

