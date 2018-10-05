//
//  MSALStorageManager.m
//  MSAL
//
//  Created by Sergey Demchenko on 10/5/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "MSALStorageManager.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDMacTokenCache.h"
#import "MSIDCredentialCacheItem.h"
#import "MSACredential.h"
#import "MSIDDefaultAccountCacheKey.h"

@interface MSALStorageManager()

@property (nonatomic) MSIDAccountCredentialCache *accountCredentialCache;

@end

@implementation MSALStorageManager

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // TODO: replace MSIDMacTokenCache with MSIDMacKeychainTokenCache (needs to implement it).
        _accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDMacTokenCache.defaultCache];
    }
    return self;
}

#pragma mark - MSAStorageManager

- (nullable MSAOperationStatus *)deleteAccount:(nonnull NSString *)correlationId homeAccountId:(nonnull NSString *)homeAccountId environment:(nonnull NSString *)environment realm:(nonnull NSString *)realm
{
    return nil;
}

- (nullable MSAOperationStatus *)deleteAccounts:(nonnull NSString *)correlationId homeAccountId:(nonnull NSString *)homeAccountId environment:(nonnull NSString *)environment
{
    return nil;
}

- (nullable MSAOperationStatus *)deleteCredentials:(nonnull NSString *)correlationId homeAccountId:(nonnull NSString *)homeAccountId environment:(nonnull NSString *)environment realm:(nonnull NSString *)realm clientId:(nonnull NSString *)clientId target:(nonnull NSString *)target types:(nonnull NSSet<NSNumber *> *)types
{
    return nil;
}

- (nullable MSAReadAccountResponse *)readAccount:(nonnull NSString *)correlationId homeAccountId:(nonnull NSString *)homeAccountId environment:(nonnull NSString *)environment realm:(nonnull NSString *)realm
{
    __auto_type key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:homeAccountId
                                                                    environment:environment realm:realm type:MSIDAccountTypeMSA];
    NSError *error;
    [_accountCredentialCache getAccount:key context:nil error:&error];
    
    if (error)
    {
        // Log error.
    }
    
    return nil;
}

- (nullable MSAReadAccountsResponse *)readAllAccounts:(nonnull NSString *)correlationId
{
    return nil;
}

- (nullable MSAReadCredentialsResponse *)readCredentials:(nonnull NSString *)correlationId homeAccountId:(nonnull NSString *)homeAccountId environment:(nonnull NSString *)environment realm:(nonnull NSString *)realm clientId:(nonnull NSString *)clientId target:(nonnull NSString *)target types:(nonnull NSSet<NSNumber *> *)types
{
    return nil;
}

- (nullable MSAOperationStatus *)writeAccount:(nonnull NSString *)correlationId account:(nullable MSAAccount *)account
{
    return nil;
}

- (nullable MSAOperationStatus *)writeCredentials:(nonnull NSString *)correlationId credentials:(nonnull NSArray<MSACredential *> *)credentials
{
    for (MSACredential *credential in credentials)
    {
        __auto_type msidCredential = [MSIDCredentialCacheItem new];
        msidCredential.clientId = [credential getClientId];
        msidCredential.environment = [credential getEnvironment];
        // etc...
        NSError *error;
        [_accountCredentialCache saveCredential:msidCredential context:nil error:&error];

        if (error)
        {
            // Log error & convert it to MSAOperationStatus.
        }
    }
    
    return nil;
}

@end
