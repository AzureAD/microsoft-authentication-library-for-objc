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
    let kCurrentUserIdentifier = "MSALCurrentUserIdentifier"
    
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
            // about the user being logged in.
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

// MARK: Current User
extension SampleMSALUtil {
    var currentUserIdentifier: String? {
        get {
            return UserDefaults.standard.string(forKey: kCurrentUserIdentifier)
        }
    }
    
    @discardableResult func currentUser() throws -> MSALUser {
        // We retrieve our current user by checking for the userIdentifier that we stored in NSUserDefaults when
        // we first signed in the user.
        if let _ = currentUserIdentifier {
            let clientApplication = try createClientApplication()
            do {
                return try clientApplication.user(forIdentifier: currentUserIdentifier)
            } catch let error as NSError {
                
                // If we did not find a user because it wasn't found in the cache then that must mean someone else removed
                // the user underneath us, either due to multiple apps sharing a client ID, or due to the user restoring an
                // image from another device. In this case it is best to detect that case and clean up local state.
                if (error.domain == MSALErrorDomain && error.code == MSALErrorCode.userNotFound.rawValue) {
                    cleanupLocalState()
                }
                
                throw SampleAppError.UserNotFound(error)
            }
        }
        else {
            // If we did not find an identifier then throw an error indicating there is no currently signed in user.
            throw SampleAppError.NoUserSignedIn
        }
    }
}

// MARK: Sign in user
extension SampleMSALUtil {
    
    func signInUser(completion: @escaping (MSALUser?, _ accessToken: String?, Error?) -> Void) {
        do {
            let application = try createClientApplication()
            
            // When signing in a user for the first time we acquire a token without providing
            // a user object. If you've previously asked the user for an email address,
            // or phone number you can provide that as a "login hint."
            
            // Request as many scopes as possible up front that you know your application will
            // want to use so the service can request consent for them up front and minimize
            // how much users are interrupted for interactive auth.
            application.acquireToken(forScopes: [GraphScopes.UserRead.rawValue, GraphScopes.CalendarsRead.rawValue], completionBlock: {
                (result: MSALResult?, error: Error?) in
                
                if let error = error {
                    completion(nil, nil, error)
                    return
                }
                
                let acquireTokenResult = result!
                
                // In the initial acquire token call we'll want to look at the user object
                // that comes back in the result.
                let signedInUser: MSALUser = acquireTokenResult.user
                
                // The userIdentifier in the MSALUser is the key to retrieve this user from
                // the cache in the future. Save this piece of information in a place you can
                // easily retrieve in your app. In this case we're going to store it in
                // NSUserDefaults.
                UserDefaults.standard.set(signedInUser.userIdentifier(), forKey: self.kCurrentUserIdentifier)
                
                completion(signedInUser, acquireTokenResult.accessToken, nil)
            })
        } catch let error {
            completion(nil, nil, error)
        }
    }
}

// MARK: Acquire Token
extension SampleMSALUtil {
    
    func acquireTokenSilentForCurrentUser(forScopes scopes:[String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        do {
            let application = try createClientApplication()
            let user = try currentUser()
            
            // Depending on how this user has been used with this application before it is possible for there to be multiple
            // tokens of varying authorities for this user in the cache. Because we are trying to get a token specifically
            // for graph in this sample it's best to specify the user's home authority to remove any possibility of there
            // being any ambiquity in the cache lookup.
            let homeAuthority = kAuthority + user.utid
            
            application.acquireTokenSilent(forScopes: scopes, user: user, authority: homeAuthority, completionBlock: {
                (result: MSALResult?, error: Error?) in
                if let result = result {
                    completion(result.accessToken, nil)
                }
                else {
                    completion(nil, error)
                }
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    func acquireTokenInteractiveForCurrentUser(forScopes scopes: [String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        do {
            let application = try createClientApplication()
            let user = try currentUser()
            
            application.acquireToken(forScopes: scopes, user: user, uiBehavior: .MSALUIBehaviorDefault, extraQueryParameters: [:], completionBlock: {
                (result: MSALResult?, error: Error?) in
                if let result = result {
                    completion(result.accessToken, nil)
                }
                else {
                    completion(nil, error)
                }
            })
        } catch let error {
            completion(nil, error)
        }
    }
    
    func acquireTokenForCurrentUser(forScopes scopes: [String], completion: @escaping (_ accessToken: String?, Error?) -> Void) {
        acquireTokenSilentForCurrentUser(forScopes: scopes) { (token: String?, error: Error?) in
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
                    self.acquireTokenInteractiveForCurrentUser(forScopes: scopes, completion: completion)
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

        var userToDelete: MSALUser?
        
        do {
            userToDelete = try currentUser()
        } catch { }
        
        cleanupLocalState()
        
        // Signing out a user requires removing this from MSAL and cleaning up any extra state that the application
        // might be maintaining outside of MSAL for the user.
        
        // This remove call only removes the user's tokens for this client ID in the local keychain cache. It does
        // not sign the user completely out of the device or remove tokens for the user for other client IDs. If
        // you have multiple applications sharing a client ID this will make the user effectively "disappear" for
        // those applications as well if you are using Keychain Cache Sharing (not currently available in MSAL
        // build preview). We do not recommend sharing a ClientID among multiple apps.
        
        if let userToDelete = userToDelete {
            let application = try createClientApplication()
            try application.remove(userToDelete)
        }
    }
    
    func cleanupLocalState() {
        
        SampleCalendarUtil.shared.clearCache()
        SamplePhotoUtil.shared.clearPhotoCache()
        
        // Leave around the user identifier as the last piece of state to clean up as you will probably need
        // it to clean up user-specific state
        UserDefaults.standard.removeObject(forKey: kCurrentUserIdentifier)
    }
}
