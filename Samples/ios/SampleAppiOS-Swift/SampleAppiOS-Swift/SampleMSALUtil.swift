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

import MSAL

// MARK: Setup and initialization
class SampleMSALUtil {
    
    let kClientId = "11744750-bfe5-4818-a1c0-655455f68fa7"
    let kCurrentAccountIdentifier = "MSALCurrentAccountIdentifier"
    
    let kAuthority = "https://login.microsoftonline.com/"
    
    // Singleton instance
    static let shared = SampleMSALUtil()
    
    // Setup
    func setup() {
        MSALLogger.shared().setCallback {
            (level: MSALLogLevel, message: String?, containsPII: Bool) in
            // If PiiLoggingEnabled is set YES, this block will be called twice; containsPII == YES and
            // containsPII == NO. In this case, you only need to capture either one set of messages.
            // however the containsPII version might contain Personally Identifiable Information (PII)
            // about the account being logged in.
            if let displayableMessage = message {
                if (!containsPII) {
                    print(displayableMessage)
                }
            }
        }
    }
}

// MARK: Create MSALPublicClientApplication
fileprivate extension SampleMSALUtil {
    func createClientApplication() throws -> MSALPublicClientApplication {
        // This MSALPublicClientApplication object is the representation of your app listing, in MSAL. For your own app
        // go to the Microsoft App Portal (TODO: Name? Link?) to register your own applications with their own client
        // IDs.
        do {
            return try MSALPublicClientApplication(clientId: kClientId)
        } catch let error as NSError {
            throw SampleAppError.PublicClientApplicationCreation(error)
        }
    }
}

// MARK: Current Account
extension SampleMSALUtil {
    var currentAccountIdentifier: String? {
        get {
            return UserDefaults.standard.string(forKey: kCurrentAccountIdentifier)
        }
        set (accountIdentifier) {
            // The identifier in the MSALAccount is the key to retrieve this user from
            // the cache in the future. Save this piece of information in a place you can
            // easily retrieve in your app. In this case we're going to store it in
            // NSUserDefaults.
            UserDefaults.standard.set(accountIdentifier, forKey: self.kCurrentAccountIdentifier)
        }
    }
    
    @discardableResult func currentAccount() throws -> MSALAccount {
        // We retrieve our current account by checking for the accountIdentifier that we stored in NSUserDefaults when
        // we first signed in the account.
        guard let accountIdentifier = currentAccountIdentifier else {
            // If we did not find an identifier then throw an error indicating there is no currently signed in account.
            throw SampleAppError.NoUserSignedIn
        }
        
        let clientApplication = try createClientApplication()
        
        do {
            return try clientApplication.account(forHomeAccountId: accountIdentifier)
        } catch let error as NSError {
            
            // If we did not find an account because it wasn't found in the cache then that must mean someone else removed
            // the account underneath us, either due to multiple apps sharing a client ID, or due to the account restoring an
            // image from another device. In this case it is best to detect that case and clean up local state.
            if (error.domain == MSALErrorDomain && error.code == MSALErrorCode.userNotFound.rawValue) {
                cleanupLocalState()
            }
            
            throw SampleAppError.UserNotFound(error)
        }
    }
    
    func clearCurrentAccount() {
        // Leave around the account identifier as the last piece of state to clean up as you will probably need
        // it to clean up user-specific state
        UserDefaults.standard.removeObject(forKey: kCurrentAccountIdentifier)
    }
}

// MARK: Sign in an account
extension SampleMSALUtil {
    
    func signInAccount(completion: @escaping (MSALAccount?, _ accessToken: String?, Error?) -> Void) {
        do {
            let clientApplication = try createClientApplication()
            
            clientApplication.acquireToken(forScopes: [GraphScopes.UserRead.rawValue, GraphScopes.CalendarsRead.rawValue]) {
                (result: MSALResult?, error: Error?) in
                
                guard let acquireTokenResult = result, error == nil else {
                    completion(nil, nil, error)
                    return
                }
                
                // In the initial acquire token call we'll want to look at the account object
                // that comes back in the result.
                let signedInAccount = acquireTokenResult.account
                self.currentAccountIdentifier = signedInAccount?.homeAccountId.identifier
                
                completion(signedInAccount, acquireTokenResult.accessToken, nil)
            }
        } catch let createApplicationError {
            completion(nil, nil, createApplicationError)
        }
    }
}

// MARK: Acquire Token
extension SampleMSALUtil {
    
    func acquireTokenSilentForCurrentAccount(forScopes scopes:[String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        do {
            let application = try createClientApplication()
            let account = try currentAccount()
            
            // Depending on how this account has been used with this application before it is possible for there to be multiple
            // tokens of varying authorities for this account in the cache. Because we are trying to get a token specifically
            // for graph in this sample it's best to specify the account's home authority to remove any possibility of there
            // being any ambiquity in the cache lookup.
            let homeAuthority = kAuthority + account.homeAccountId.tenantId

            let msalAuthority = try MSALAuthority(url: URL(string: homeAuthority)!)
            
            application.acquireTokenSilent(forScopes: scopes, account: account, authority: msalAuthority, completionBlock: {
                (result: MSALResult?, error: Error?) in
                guard let acquireTokenResult = result, error == nil else {
                    completion(nil, error)
                    return
                }
      
                completion(acquireTokenResult.accessToken, nil)
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    func acquireTokenInteractiveForCurrentAccount(forScopes scopes: [String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        do {
            let application = try createClientApplication()
            let account = try currentAccount()
            
            application.acquireToken(forScopes: scopes, account: account, uiBehavior: .MSALUIBehaviorDefault, extraQueryParameters: [:], completionBlock: {
                (result: MSALResult?, error: Error?) in
                
                guard let acquireTokenResult = result, error == nil else {
                    completion(nil, error)
                    return
                }
                
                completion(acquireTokenResult.accessToken, nil)
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    func acquireTokenForCurrentAccount(forScopes scopes: [String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        acquireTokenSilentForCurrentAccount(forScopes: scopes) {
            (token: String?, error: Error?) in
            if let token = token {
                completion(token, nil)
                return
            }
            
            // What an app does on an InteractionRequired error will vary from app to app. Most apps
            // will want to present a notification to the user in an unobtrusive way (such as on a
            // status bar in the application UI) before bringing up the modal interactive login dialog,
            // otherwise it can appear to be out of context for the user, and confuse them as to why
            // they are seeing an authentication prompt.
            
            let nsError = error! as NSError

            if (nsError.domain == MSALErrorDomain &&
                nsError.code == MSALErrorCode.interactionRequired.rawValue) {
                DispatchQueue.main.async {
                    self.acquireTokenInteractiveForCurrentAccount(forScopes: scopes, completion: completion)
                }
                return
            }
            
            completion(nil, error)
        }
    }
}

// MARK: Sign out and clean up
extension SampleMSALUtil {
    
    func signOut() throws {

        cleanupLocalState()
        
        let accountToDelete = try? currentAccount()
        
        // Signing out an account requires removing this from MSAL and cleaning up any extra state that the application
        // might be maintaining outside of MSAL for the account.
        
        // This remove call only removes the account's tokens for this client ID in the local keychain cache. It does
        // not sign the account completely out of the device or remove tokens for the account for other client IDs. If
        // you have multiple applications sharing a client ID this will make the account effectively "disappear" for
        // those applications as well if you are using Keychain Cache Sharing (not currently available in MSAL
        // build preview). We do not recommend sharing a ClientID among multiple apps.
        
        if let accountToDelete = accountToDelete {
            let application = try createClientApplication()
            try application.remove(accountToDelete)
        }
    }
    
    fileprivate func cleanupLocalState() {
        
        SampleCalendarUtil.shared.clearCache()
        SamplePhotoUtil.shared.clearPhotoCache()
        
        self.clearCurrentAccount()
    }
}
