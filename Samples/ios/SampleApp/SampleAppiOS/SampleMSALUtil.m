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

#import <MSAL/MSAL.h>

#import "SampleMSALUtil.h"
#import "SampleAppErrors.h"
#import "SampleCalendarUtil.h"
#import "SamplePhotoUtil.h"

#define CURRENT_ACCOUNT_KEY @"MSALCurrentAccountIdentifier"
#define CLIENT_ID @"11744750-bfe5-4818-a1c0-655455f68fa7"

@implementation SampleMSALUtil

+ (instancetype)sharedUtil
{
    static SampleMSALUtil *s_sharedUtil = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_sharedUtil = [SampleMSALUtil new];
    });
    
    return s_sharedUtil;
}

+ (void)setup
{
    [[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII)
    {
        // If PiiLoggingEnabled is set YES, this block will be called twice; containsPII == YES and
        // containsPII == NO. In this case, you only need to capture either one set of messages.
        // however the containsPII version might contain Personally Identifiable Information (PII)
        // about the account being logged in.
        
        // if message is "redirect to https://somehost.com",
        if (!containsPII)
        {
            // WILL CONTAIN EVERYTHING
            // so message contains "redirect to https://somehost.com"
            NSLog(@"%@", message);
        }
        
        else
        {
            // message contains "redirect to unknown host" or "redirect to (non-nil)"
        }
    }];
}

- (MSALPublicClientApplication *)createClientApplication
{
    // This MSALPublicClientApplication object is the representation of your app listing, in MSAL. For your own app
    // go to the Microsoft App Portal (TODO: Name? Link?) to register your own applications with their own client
    // IDs.
    return [[MSALPublicClientApplication alloc] initWithClientId:CLIENT_ID error:nil];
}

- (NSString *)currentAccountIdentifer
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:CURRENT_ACCOUNT_KEY];
}

- (MSALAccount *)currentAccount:(NSError *__autoreleasing *)error
{
    // We retrieve our current account by checking for the accountIdentifier that we stored in NSUserDefaults when
    // we first signed in the account.
    NSString *currentAccountIdentifer = [self currentAccountIdentifer];
    if (!currentAccountIdentifer)
    {
        // If we did not find an identifier then return nil with a no account signed
        // in error specific for the application.
        if (error)
        {
            *error = [NSError errorWithDomain:SampleAppErrorDomain code:SampleAppNoUserSignedIn userInfo:nil];
        }
        
        return nil;
    }
    
    // Because error is an optional parameter we need to pass in our own error pointer to make sure we get
    // an error back so we can inspect it after.
    NSError *localError = nil;
    
    // Ask MSALPublicClientApplication object to retrieve the account from the cache.
    MSALAccount *account = [[self createClientApplication] accountForHomeAccountId:currentAccountIdentifer error:&localError];
    
    // If we did not find an account because it wasn't found in the cache then that must mean someone else removed
    // the account underneath us, either due to multiple apps sharing a client ID, or due to the account restoring an
    // image from another device. In this case it is best to detect that case and clean up local state.
    if (!account && [localError.domain isEqualToString:MSALErrorDomain] && localError.code == MSALErrorUserNotFound)
    {
        [self cleanupLocalState];
    }
    
    // NSError ** is traditionally an optional parameters, so we should check to make sure it is not nil before
    // filling it.
    if (error)
    {
        *error = localError;
    }
    
    return account;
}

- (void)signInAccount:(void (^)(MSALAccount *account, NSString *token, NSError *error))signInBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    // When signing in an account for the first time we acquire a token without providing
    // an account object. If you've previously asked the user for an email address,
    // or phone number you can provide that as a "login hint."
    
    // Request as many scopes as possible up front that you know your application will
    // want to use so the service can request consent for them up front and minimize
    // how much users are interrupted for interactive auth.
    [application acquireTokenForScopes:@[@"User.Read", @"Calendars.Read"]
                       completionBlock:^(MSALResult *result, NSError *error)
    {
        if (error)
        {
            signInBlock(nil, nil, error);
            return;
        }
        
        // In the initial acquire token call we'll want to look at the account object
        // that comes back in the result.
        MSALAccount *account = result.account;
        
        // The identifier in the MSALAccount is the key to retrieve this account from
        // the cache in the future. Save this piece of information in a place you can
        // easily retrieve in your app. In this case we're going to store it in
        // NSUserDefaults.
        [[NSUserDefaults standardUserDefaults] setValue:account.homeAccountId.identifier forKey:CURRENT_ACCOUNT_KEY];
        
        signInBlock(account, result.accessToken, error);
    }];
}

- (void)acquireTokenSilentForCurrentAccount:(NSArray<NSString *> *)scopes
                            completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALAccount *currentAccount = [self currentAccount:&error];
    if (!currentAccount)
    {
        acquireTokenBlock(nil, error);
        return;
    }
    
    // Depending on how this account has been used with this application before it is possible for there to be multiple
    // tokens of varying authorities for this account in the cache. Because we are trying to get a token specifically
    // for graph in this sample it's best to specify the account's home authority to remove any possibility of there
    // being any ambiquity in the cache lookup.
    NSString *homeAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", currentAccount.homeAccountId.tenantId];
    
    [application acquireTokenSilentForScopes:scopes
                                     account:currentAccount
                                   authority:homeAuthority
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
    {
        acquireTokenBlock(result.accessToken, error);
    }];
}

- (void)acquireTokenInteractiveForCurrentAccount:(NSArray<NSString *> *)scopes
                                 completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALAccount *currentAccount = [self currentAccount:&error];
    if (!currentAccount)
    {
        acquireTokenBlock(nil, error);
        return;
    }

    [application acquireTokenForScopes:scopes
                               account:currentAccount
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         acquireTokenBlock(result.accessToken, error);
     }];
}

- (void)acquireTokenForCurrentAccount:(NSArray<NSString *> *)scopes
                      completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    [self acquireTokenSilentForCurrentAccount:scopes
                              completionBlock:^(NSString *token, NSError *error)
     {
         if (!error)
         {
             acquireTokenBlock(token, nil);
             return;
         }
         
         // What an app does on an InteractionRequired error will vary from app to app. Most apps
         // will want to present a notification to the account in an unobtrusive way (such as on a
         // status bar in the application UI) before bringing up the modal interactive login dialog,
         // otherwise it can appear to be out of context for the account, and confuse them as to why
         // they are seeing an authentication prompt.
         if ([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorInteractionRequired)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self acquireTokenInteractiveForCurrentAccount:scopes
                                                completionBlock:acquireTokenBlock];
             });
             return;
         }
         
         acquireTokenBlock(nil, error);
     }];
}

- (void)signOut

{
    MSALPublicClientApplication *application = [self createClientApplication];
    MSALAccount *currentAccount = [self currentAccount:nil];
    [self cleanupLocalState];
    
    // Signing out an account requires removing this from MSAL and cleaning up any extra state that the application
    // might be maintaining outside of MSAL for the account.
    
    // This remove call only removes the account's tokens for this client ID in the local keychain cache. It does
    // not sign the account completely out of the device or remove tokens for the account for other client IDs. If
    // you have multiple applications sharing a client ID this will make the account effectively "disappear" for
    // those applications as well if you are using Keychain Cache Sharing (not currently available in MSAL
    // build preview). We do not recommend sharing a ClientID among multiple apps.
    [application removeAccount:currentAccount error:nil];
    
}

- (void)cleanupLocalState
{
    [[SamplePhotoUtil sharedUtil] clearPhotoCache];
    [[SampleCalendarUtil sharedUtil] clearCache];
    
    // Leave around the account identifier as the last piece of state to clean up as you will probably need
    // it to clean up user-specific state
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CURRENT_ACCOUNT_KEY];
}

@end
