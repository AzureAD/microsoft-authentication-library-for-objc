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

#import <Foundation/Foundation.h>
#import "MSALExternalAccountProviding.h"

/**
    Specifies if MSALLegacySharedAccountsProvider will attempt to write/remove accounts.
 */

typedef NS_ENUM(NSInteger, MSALLegacySharedAccountMode)
{
    /**
        MSALLegacySharedAccountsProvider will operate in a read-only mode.
     */
    MSALLegacySharedAccountModeReadOnly = 0,
    
    /**
       MSALLegacySharedAccountsProvider will operate in a read-write mode.
    */
    MSALLegacySharedAccountModeReadWrite
};

NS_ASSUME_NONNULL_BEGIN

/**
 Sample implementation of the MSALExternalAccountProviding protocol that can work with legacy Microsoft account storage.
 Use it if:
 1. You're migrating from ADAL to MSAL and where previously relying on shared Microsoft account storage.
    In that case, usage of this class should be temporary, until more than X% of users migrate to MSAL (X can be 95% depending on your app requirements).
 2. As sample code to implement your own MSALExternalAccountProviding
 */
@interface MSALLegacySharedAccountsProvider : NSObject <MSALExternalAccountProviding>

#pragma mark - Switching between read-write and read-only modes

/**
 Specifies if MSALLegacySharedAccountsProvider will attempt to write/remove accounts.
 Set to MSALLegacySharedAccountModeReadWrite to attempt writing accounts
 Default is MSALLegacySharedAccountModeReadOnly, which means MSALLegacySharedAccountsProvider will not modify external account storage
 */
@property (nonatomic) MSALLegacySharedAccountMode sharedAccountMode;

#pragma mark - Constructing MSALLegacySharedAccountsProvider

/**
 Initialize new instance of MSALLegacySharedAccountsProvider.
 
 @param sharedGroup             Specify keychain access group from which accounts will be read.
 @param serviceIdentifier       Specify unique account entry identifier in the keychain (each keychain entry is identifier by "account" and "service" parameters, this is the "service" part of it)
 @param applicationIdentifier   Your application name for logging and storage purposes.
 
 After initialization, set it in the MSALCacheConfig class, e.g.
 
 <pre>
 MSALLegacySharedAccountsProvider *provider = [[MSALLegacySharedAccountsProvider alloc] initWithSharedKeychainAccessGroup:@"com.mycompany.mysso"
                                                                                                        serviceIdentifier:@"MyAccountServiceIdentifier"
                                                                                                    applicationIdentifier:@"MyApp"];
 
 MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                redirectUri:redirectUri
                                                                                                  authority:authority];
 
 [pcaConfig.cacheConfig addExternalAccountProvider:provider];
 MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
 </pre>
 
 */
- (instancetype)initWithSharedKeychainAccessGroup:(NSString *)sharedGroup
                                serviceIdentifier:(NSString *)serviceIdentifier
                            applicationIdentifier:(NSString *)applicationIdentifier;

@end

NS_ASSUME_NONNULL_END
