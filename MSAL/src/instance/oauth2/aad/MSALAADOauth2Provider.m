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

#import "MSALAADOauth2Provider.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALOauth2Provider+Internal.h"
#import "MSALResult+Internal.h"
#import "MSIDAuthority.h"
#import "MSALAADAuthority.h"
#import "MSIDTokenResult.h"
#import "NSURL+MSIDAADUtils.h"
#import "MSALAccount.h"
#import "MSALAccountId.h"
#import "MSIDAADAuthority.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALErrorConverter.h"
#import "MSIDAccountMetadataCacheAccessor.h"

@implementation MSALAADOauth2Provider

#pragma mark - Public

- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)tokenResult
                                error:(NSError **)error
{
    NSError *authorityError = nil;
    
    MSALAADAuthority *aadAuthority = [[MSALAADAuthority alloc] initWithURL:tokenResult.authority.url error:&authorityError];
    
    if (!aadAuthority)
    {
        MSID_LOG_NO_PII(MSIDLogLevelWarning, nil, nil, @"Invalid authority");
        MSID_LOG_PII(MSIDLogLevelWarning, nil, nil, @"Invalid authority, error %@", authorityError);
        
        if (error) *error = authorityError;
        
        return nil;
    }
    
    return [MSALResult resultWithMSIDTokenResult:tokenResult authority:aadAuthority error:error];
}

- (BOOL)removeAdditionalAccountInfo:(MSALAccount *)account
                              error:(NSError **)error
{
    // If we remove account, we want this app to be also disassociated from foci token, so that user cannot sign in silently again after signing out
    // Therefore, we update app metadata to not have family id for this app after signout
    
    NSURL *authorityURL = [NSURL msidAADURLWithEnvironment:account.environment tenant:account.homeAccountId.tenantId];
    MSIDAADAuthority *aadAuthority = [[MSIDAADAuthority alloc] initWithURL:authorityURL rawTenant:nil context:nil error:nil];
    
    NSError *metadataError = nil;
    BOOL metadataResult = [self.tokenCache updateAppMetadataWithFamilyId:@""
                                                                clientId:self.clientId
                                                               authority:aadAuthority
                                                                 context:nil
                                                                   error:&metadataError];
    
    if (!metadataResult)
    {
        if (error)
        {
            *error = metadataError;
        }
        
        MSID_LOG_WARN(nil, @"Failed to update app metadata when removing account %ld, %@", (long)metadataError.code, metadataError.domain);
        MSID_LOG_WARN(nil, @"Failed to update app metadata when removing account %@", metadataError);
        return NO;
    }
    
    return YES;
}

- (MSIDAuthority *)issuerAuthorityWithAccount:(MSALAccount *)account
                             requestAuthority:(MSIDAuthority *)requestAuthority
                                        error:(NSError **)error
{
    NSError *localError;
    NSURL *cachedURL = [self.accountMetadataCache getAuthorityURL:requestAuthority.url
                                                    homeAccountId:account.homeAccountId.identifier
                                                         clientId:self.clientId
                                                          context:nil
                                                            error:&localError];
    if (cachedURL)
    {
        return [[MSIDAADAuthority alloc] initWithURL:cachedURL
                                           rawTenant:nil
                                             context:nil
                                               error:error];
    }
    
    if (localError)
    {
        MSID_LOG_WARN(nil, @"error accessing accountMetadataCache - %@", localError);
    }
    
    /*
     In the acquire token silent call we assume developer wants to get access token for account's home tenant,
     if authority is a common, organizations or consumers authority.
     */
    return [[MSIDAADAuthority alloc] initWithURL:requestAuthority.url
                                       rawTenant:account.homeAccountId.tenantId
                                         context:nil
                                           error:error];
}

- (BOOL)isSupportedAuthority:(MSIDAuthority *)authority
{
    return [authority isKindOfClass:[MSIDAADAuthority class]];
}

#pragma mark - Protected

- (void)initOauth2Factory
{
    self.msidOauth2Factory = [MSIDAADV2Oauth2Factory new];
}

@end
