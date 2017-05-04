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

#define CURRENT_USER_KEY @"MSALCurrentUserIdentifier"
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
        // When capturing log messages from MSAL you only need to capture either messages where
        // containsPII == YES or containsPII == NO, as log messages are duplicated between the
        // two, however the containsPII version might contain Personally Identifiable Information (PII)
        // about the user being logged in.
        if (!containsPII)
        {
            NSLog(@"%@", message);
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

- (NSString *)currentUserIdentifer
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:CURRENT_USER_KEY];
}

- (MSALUser *)currentUser:(NSError * __autoreleasing *)error
{
    // We retrieve our current user by checking for the userIdentifier that we stored in NSUserDefaults when
    // we first signed in the user.
    NSString *currentUserIdentifier = [self currentUserIdentifer];
    if (!currentUserIdentifier)
    {
        // If we did not find an identifier then return nil with a no user signed
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
    
    // Ask MSALPublicClientApplication object to retrieve the user from the cache.
    MSALUser *user = [[self createClientApplication] userForIdentifier:currentUserIdentifier error:&localError];
    
    // If we did not find a user because it wasn't found in the cache then that must mean someone else removed
    // the user underneath us, either due to multiple apps sharing a client ID, or due to the user restoring an
    // image from another device. In this case it is best to detect that case and clean up local state.
    if (!user && [localError.domain isEqualToString:MSALErrorDomain] && localError.code == MSALErrorUserNotFound)
    {
        [self cleanupLocalState];
    }
    
    // NSError ** is traditionally an optional parameters, so we should check to make sure it is not nil before
    // filling it.
    if (error)
    {
        *error = localError;
    }
    
    return user;
}

- (void)signInUser:(void (^)(MSALUser *user, NSString *token, NSError *error))signInBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    // When signing in a user for the first time we acquire a token without providing
    // a user object. If you've previously asked the user for an email address,
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
        
        // In the initial acquire token call we'll want to look at the user object
        // that comes back in the result.
        MSALUser *user = result.user;
        
        // The userIdentifier in the MSALUser is the key to retrieve this user from
        // the cache in the future. Save this piece of information in a place you can
        // easily retrieve in your app. In this case we're going to store it in
        // NSUserDefaults.
        [[NSUserDefaults standardUserDefaults] setValue:user.userIdentifier forKey:CURRENT_USER_KEY];
        
        signInBlock(user, result.accessToken, error);
    }];
}

- (void)acquireTokenSilentForCurrentUser:(NSArray<NSString *> *)scopes
                         completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALUser *currentUser = [self currentUser:&error];
    if (!currentUser)
    {
        acquireTokenBlock(nil, error);
        return;
    }
    
    // Depending on how this user has been used with this application before it is possible for there to be multiple
    // tokens of varying authorities for this user in the cache. Because we are trying to get a token specifically
    // for graph in this sample it's best to specify the user's home authority to remove any possibility of there
    // being any ambiquity in the cache lookup.
    NSString *homeAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", currentUser.utid];
    
    [application acquireTokenSilentForScopes:scopes
                                        user:currentUser
                                   authority:homeAuthority
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
    {
        acquireTokenBlock(result.accessToken, error);
    }];
}

- (void)acquireTokenInteractiveForCurrentUser:(NSArray<NSString *> *)scopes
                              completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALUser *currentUser = [self currentUser:&error];
    if (!currentUser)
    {
        acquireTokenBlock(nil, error);
        return;
    }

    [application acquireTokenForScopes:scopes
                                  user:currentUser
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         acquireTokenBlock(result.accessToken, error);
     }];
}

- (void)acquireTokenForCurrentUser:(NSArray<NSString *> *)scopes
                   completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    [self acquireTokenSilentForCurrentUser:scopes
                           completionBlock:^(NSString *token, NSError *error)
     {
         if (!error)
         {
             acquireTokenBlock(token, nil);
             return;
         }
         
         // What an app does on an InteractionRequired error will vary from app to app. Most apps
         // will want to present a notification to the user in an unobtrusive way (such as on a
         // status bar in the application UI) before bringing up the modal interactive login dialog,
         // otherwise it can appear to be out of context for the user, and confuse them as to why
         // they are seeing an authentication prompt.
         if ([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorInteractionRequired)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self acquireTokenInteractiveForCurrentUser:scopes
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
    MSALUser *currentUser = [self currentUser:nil];
    [self cleanupLocalState];
    
    // Signing out a user requires removing this from MSAL and cleaning up any extra state that the application
    // might be maintaining outside of MSAL for the user.
    
    // This remove call only removes the user's tokens for this client ID in the local keychain cache. It does
    // not sign the user completely out of the device or remove tokens for the user for other client IDs. If
    // you have multiple applications sharing a client ID this will make the user effectively "disappear" for
    // those applications as well if you are using Keychain Cache Sharing (not currently available in MSAL
    // build preview). We do not recommend sharing a ClientID among multiple apps.
    [application removeUser:currentUser error:nil];
    
}

- (void)cleanupLocalState
{
    [[SamplePhotoUtil sharedUtil] clearPhotoCache];
    [[SampleCalendarUtil sharedUtil] clearCache];
    
    // Leave around the user identifier as the last piece of state to clean up as you will probably need
    // it to clean up user-specific state
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CURRENT_USER_KEY];
}

@end
