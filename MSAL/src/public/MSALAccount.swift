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

import MSAL_Private

import Foundation

/**
    Representation of an authenticated account in the Microsoft identity platform.
    Use MSALAccount to query information about the account, like username or id_token claims.
    Store `identifier` for getting tokens silently from MSAL at a later point.

    @note For a list of standard id_token claims in the Microsoft Identity platform, see https://docs.microsoft.com/en-us/azure/active-directory/develop/id-tokens
*/

@objc internal protocol MSALAccountProtocol : NSObjectProtocol {

    /**
     Shorthand name by which the End-User wishes to be referred to at the RP, such as janedoe or j.doe. This value MAY be any valid JSON string including special characters such as @, /, or whitespace.
     Mostly maps to UserPrincipleName(UPN) in case of AAD.
     Can be nil if not returned from the service.
     */

    var username: String? { get }

    /**
     Unique identifier for the account.
     Save this for account lookups from cache at a later point.
     */

    var identifier: String? { get }

    /**
     Host part of the authority string used for authentication based on the issuer identifier.
     Note that if a host supports multiple tenants, there'll be one MSALAccount for the host and one tenant profile per each tenant accessed (see MSALAccount+MultiTenantAccount.h header)
     If a host doesn't support multiple tenants, there'll be one MSALAccount with accountClaims returned.

     e.g. if app accesses following tenants: Contoso.com and MyOrg.com in the Public AAD cloud, there'll be following information returned:

     MSALAccount
     - environment of "login.microsoftonline.com"
     - identifier based on the GUID of "MyOrg.com"
     - accountClaims from the id token for the "MyOrg.com"
     - tenantProfiles
     - tenantProfile[0]
     - identifier based on account identifiers from "MyOrg.com" (account object id in MyOrg.com and tenant Id for MyOrg.com directory)
     - claims for the id token issued by MyOrg.com
     - tenantProfile[1]
     - identifier based on account identifiers from "Contoso.com"
     - claims for the id token issued by Contoso.com
     */

    var environment: String? { get }

    /**
     ID token claims for the account.
     Can be used to read additional information about the account, e.g. name
     Will only be returned if there has been an id token issued for the client Id for the account's source tenant.

     */

    var accountClaims: [String: Any]? { get }

}

/**
    Representation of an authenticated account in the Microsoft identity platform. MSALAccount class implements `MSALAccount` protocol.
    @note MSALAccount should be never created directly by an application.
    Instead, it is returned by MSAL as a result of getting a token interactively or silently (see `MSALResult`), or looked up by MSAL from cache (e.g. see `-[MSALPublicClientApplication allAccounts:]`)
  */

@objcMembers
public final class MSALAccount : NSObject, MSALAccountProtocol {
    @objc public var username: String?
    @objc public var identifier: String?
    @objc public var environment: String?
    @objc public var accountClaims: [String : Any]?
    @objc public var homeAccountId: MSALAccountId?
    @objc public var mTenantProfiles: [String : MSALTenantProfile]?
    @objc public var lookupAccountIdentifier: MSIDAccountIdentifier?
    @objc public var isSSOAccount : Bool = false

    //@available(*, unavailable)
    override init() {
        //fatalError("Init is unavailable")
    }

   public convenience init(
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

    public convenience init(
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
    
    public convenience init(
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

    public convenience init(
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

    // MARK: - NSObject

    public override func isEqual(_ object: (Any)?) -> Bool {
        guard let other = object as? MSALAccount else {
            return false
        }
        return isEqualTo(user: other)
    }

    public override var hash : Int {
        let hash = 0
        // Equality of MSALAccount is depending on equality of homeAccountId or username
        // So we are not able to calculate a precise hash
        return hash
    }

    func isEqualTo(user: MSALAccount?) -> Bool {
        guard let user else {
            return false
        }

        return self.username == user.username && self.homeAccountId == user.homeAccountId
    }
    
    public func tenantProfiles() -> [MSALTenantProfile]? {
        return mTenantProfiles?.values as? [MSALTenantProfile]
    }

    public func addTenantProfiles(_ tenantProfiles: [MSALTenantProfile]?) {
        if (tenantProfiles?.count ?? 0) <= 0 {
            return
        }

        if mTenantProfiles == nil {
            mTenantProfiles = [String : MSALTenantProfile]()
        }

        for profile in tenantProfiles ?? [] {
            if let tenantId = profile.tenantId, mTenantProfiles?[tenantId] == nil {
                mTenantProfiles?[tenantId] = profile
            }
        }
    }
}


class MSALLegacySharedADALAccount : MSALLegacySharedAccount {

}

