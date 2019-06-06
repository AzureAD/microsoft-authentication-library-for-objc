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

#import "MSALB2COauth2Provider.h"
#import "MSALOauth2Provider+Internal.h"
#import "MSIDB2COauth2Factory.h"
#import "MSALResult+Internal.h"
#import "MSIDAuthority.h"
#import "MSALB2CAuthority_Internal.h"
#import "MSIDTokenResult.h"
#import "MSIDB2CAuthority.h"
#import "MSALAccount.h"
#import "MSALAccountId.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccountIdentifier.h"

@implementation MSALB2COauth2Provider

#pragma mark - Public

- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)tokenResult
                                error:(NSError **)error
{
    NSError *authorityError = nil;
    
    MSALB2CAuthority *b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:tokenResult.authority.url validateFormat:NO error:&authorityError];
    
    if (!b2cAuthority)
    {
        MSID_LOG_NO_PII(MSIDLogLevelWarning, nil, nil, @"Invalid authority");
        MSID_LOG_PII(MSIDLogLevelWarning, nil, nil, @"Invalid authority, error %@", authorityError);
        
        if (error) *error = authorityError;
        
        return nil;
    }
    
    return [MSALResult resultWithMSIDTokenResult:tokenResult authority:b2cAuthority error:error];
}

- (MSIDAuthority *)issuerAuthorityWithAccount:(MSALAccount *)account
                             requestAuthority:(MSIDAuthority *)requestAuthority
                                        error:(NSError **)error
{
    if (self.accountMetadataCache)
    {
        NSURL *cachedURL = [self.accountMetadataCache getAuthorityURL:requestAuthority.url
                                                        homeAccountId:account.homeAccountId.identifier
                                                             clientId:self.clientId
                                                              context:nil
                                                                error:error];
        if (!cachedURL) return requestAuthority;
        return [[MSIDB2CAuthority alloc] initWithURL:cachedURL?:requestAuthority.url
                                      validateFormat:NO
                                           rawTenant:nil
                                             context:nil
                                               error:error];
    }
    return requestAuthority;
}

- (BOOL)isSupportedAuthority:(MSIDAuthority *)authority
{
    return [authority isKindOfClass:[MSIDB2CAuthority class]];
}

#pragma mark - Protected

- (void)initOauth2Factory
{
    self.msidOauth2Factory = [MSIDB2COauth2Factory new];
}

@end
