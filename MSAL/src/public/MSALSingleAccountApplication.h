//
//  MSALSingleAccountApplication.h
//  MSAL (iOS Framework)
//
//  Created by Olga Dalton on 11/23/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <MSAL/MSAL.h>

NS_ASSUME_NONNULL_BEGIN

@class MSALSingleAccountApplication;
@class MSALAccount;
@class MSALPublicClientApplicationConfig;

typedef void (^MSALCurrentAccountLoadedCallback)(NSError *error, BOOL accountChanged, MSALAccount * _Nullable newAccount, MSALAccount * _Nullable oldAccount);

/*
 MSALPublicClientApplication interface that focuses on a single account
 Account set in this class will be used for all operations and associated with the client_id
 */
@interface MSALSingleAccountApplication : MSALPublicClientApplication

/*
 Current account will be updated either through initializer, or after calling loadCurrentAccountWithCompletionBlock:
 */
@property (nonatomic, readonly) MSALAccount *currentAccount; // this behaves as "default account" on non-shared devices, and as the only possible account on shared devices.

/*
 Refreshes current account if present.
 Useful when application comes to foreground to check if account is still signed in.
 */
- (void)loadCurrentAccountWithCompletionBlock:(nonnull MSALCurrentAccountLoadedCallback)completionBlock;

/*
 Initializes application with a configuration.
 Will use a provided account identifier for all operations.
 If account is not found, will return InteractionRequired error in silent operation and expect developer to call interactive token acquisition API.
 */
- (nullable instancetype)initWithConfiguration:(nonnull MSALPublicClientApplicationConfig *)config
                             accountIdentifier:(nullable NSString *)accountIdentifier
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

// Init MSALSingleAccountApplication
// call acquireTokenSilent (pass currentAccount)
// if get back interactionRequired, call back acquireTokenInteractive passing currentAccount

// Non shared device
// Multiple accounts
// If non-shared device, and call acquireTokenSilent with a different account, fulfill the request

// AT/ATS logic: If nil account in params, use currentAccount
// If non-nil account in params, and non-shared device, use that account
// On a shared device, If non-nil account in params, and same as currentAccount, use that account
// On a shared device, If non-nil account in params, and different from currentAccount, fail silent with InteractionRequired (since there're no tokens anymore), show picker for interactive.

/* App scenarios. If my app only supports single account:
1. I use MSALSingleAccountApplication
2. On app launch, I create MSALSingleAccountApplication(), and call loadCurrentAccountWithCompletionBlock API (or acquireTokenSilent to avoid an extra step?)
3. If account is nil, I call acquireTokenInteractive
4. If account is non-nil, I call acquireTokenSilent
Works on shared and non-shared devices. Same as current MSAL, except I don't need to store account Identifier.
 
 // On app launch
 
 getToken()
 
 ....
 
 func getToken() {
 
 let app = MSALSingleAccountApplication(config: config)
 app.acquireTokenSilent(params, completion:^(result, error) {
        if error == InteractionRequired {
            app.acquireTokenInteractive(params)
            return
        }
 
        let account = result.account
        let username = account.username
        loadUserData()
    }
 }
 
 // On app foreground
 app.loadCurrentAccountWithCompletionBlock:^(error, accountChanged, newAccount, oldAccount ...) {
 
        if accountChanged {
 
            clearOldAccountData()
            getToken()
        }
 }
 
If my app supports multiple accounts, but on shared devices wants to support single account only.
1. I use MSALSingleAccountApplication
2. On app launch, I create MSALSingleAccountApplication() and call loadDeviceStateWithCompletionBlock API (I have multiple account identifiers cached in my storage with one being the primary one).
3. If device is shared, I follow the previous path
4. If device is non-shared, I call normal acquireTokenSilent API with my account Id
5. On a shared device, I'll never have multiple accounts because my tokens will be wiped for me (or we mark an account as shared, and only return that one)

NS_ASSUME_NONNULL_END
