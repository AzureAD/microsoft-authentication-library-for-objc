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

#import <MSALNativeAuthUserAccountResult.h>
#import <Foundation/Foundation.h>
#import "MSALAccount.h"


@implementation MSALNativeAuthUserAccountResult

- (nonnull instancetype)initWithTest:(nonnull NSString *)test {
    self = [super init];
    return self;
}


- (instancetype)initWithAccount:(MSALAccount *)account
                     authTokens:(MSALNativeAuthTokens *)authTokens
                  configuration:(MSALNativeAuthConfiguration *)configuration
                  cacheAccessor:(MSALNativeAuthCacheInterface  *)cacheAccessor {
    self = [super init];
    if (self) {
        self.account = account;
        self.authTokens = authTokens;
        self.configuration = configuration;
        self.cacheAccessor = cacheAccessor;
    }
    return self;
}

- (void)getAccessTokenWithForceRefresh:(BOOL)forceRefresh
                           correlationId:(NSUUID *)correlationId
                                delegate:(CredentialsDelegate *) delegate {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulating async operation
        /*
        MSALControllerResponse *controllerResponse = [self getAccessTokenInternalWithForceRefresh:forceRefresh
                                                                                 correlationId:correlationId
                                                                                  cacheAccessor:self.cacheAccessor];

        CredentialsDelegateDispatcher *delegateDispatcher = [[CredentialsDelegateDispatcher alloc] initWithDelegate:delegate
                                                                                                   telemetryUpdate:controllerResponse.telemetryUpdate];

        if (controllerResponse.result == MSALResultSuccess) {
            [delegateDispatcher dispatchAccessTokenRetrieveCompletedWithAccessToken:controllerResponse.accessToken
                                                                      correlationId:controllerResponse.correlationId];
        } else {
            [delegate onAccessTokenRetrieveErrorWithError:controllerResponse.error];
        }*/
    });
}

- (void)signOut {/*
    MSALNativeAuthRequestContext *context = [[MSALNativeAuthRequestContext alloc] init];

    @try {
        [cacheAccessor clearCacheWithAccountIdentifier:account.lookupAccountIdentifier
                                              authority:configuration.authority
                                               clientId:configuration.clientId
                                                context:context];
    } @catch (NSException *exception) {
        [MSALLogger logWithLevel:MSALLogLevelError
                          context:context
                           format:@"Clearing MSAL token cache for the current account failed with error %@: %@", [exception name], [exception reason]];
    }
                  */
}

- (NSString *)getAccessTokenInternal:(BOOL)forceRefresh
                                                                                       correlationId:(NSUUID *)correlationId
                                                                                      cacheAccessor:(MSALNativeAuthCacheInterface *)cacheAccessor {
    /*
    MSALNativeAuthRequestContext *context = [[MSALNativeAuthRequestContext alloc] initWithCorrelationId:correlationId];
    NSUUID *correlationId = [context correlationId];

    if (self.authTokens.accessToken) {
        if (forceRefresh || [accessToken isExpired]) {
            MSALNativeAuthControllerFactory *controllerFactory = [[MSALNativeAuthControllerFactory alloc] initWithConfig:configuration];
            id<MSALNativeAuthCredentialsControlling> credentialsController = [controllerFactory makeCredentialsControllerWithCacheAccessor:cacheAccessor];
            return [credentialsController refreshTokenWithContext:context authTokens:self.authTokens];
        } else {
            return [[MSALNativeAuthCredentialsControllingRefreshTokenCredentialControllerResponse alloc] initWithResult:[[MSALResult alloc] initWithSuccess:self.authTokens.accessToken.accessToken] correlationId:correlationId];
        }
    } else {
        [MSALLogger logWithLevel:MSALLogLevelError context:context format:@"Retrieve Access Token: Existing token not found"];
        return [[MSALNativeAuthCredentialsControllingRefreshTokenCredentialControllerResponse alloc] initWithResult:[[MSALResult alloc] initWithFailure:[[RetrieveAccessTokenError alloc] initWithType:RetrieveAccessTokenErrorTypeTokenNotFound correlationId:correlationId]] correlationId:correlationId];
    }*/
    return @"";
}


@end
