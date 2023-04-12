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

#import "MSALOauth2ProviderFactory.h"
#import "MSALB2CAuthority.h"
#import "MSALAADAuthority.h"
#import "MSALADFSAuthority.h"
#import "MSALB2COauth2Provider.h"
#import "MSALAADOauth2Provider.h"
#import "MSALCIAMOauth2Provider.h"
#import "MSALADFSAuthority.h"
#import "MSALCIAMAuthority.h"

@implementation MSALOauth2ProviderFactory

+ (MSALOauth2Provider *)oauthProviderForAuthority:(MSALAuthority *)authority
                                         clientId:(NSString *)clientId
                                       tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                             accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                                          context:(__unused id<MSIDRequestContext>)context
                                            error:(NSError **)error
{
    if (!authority)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Provided authority url is nil.", nil);
        
        return nil;
    }
    
    if ([authority isKindOfClass:[MSALB2CAuthority class]])
    {
        return [[MSALB2COauth2Provider alloc] initWithClientId:clientId tokenCache:tokenCache accountMetadataCache:accountMetadataCache];
    }
    else if ([authority isKindOfClass:[MSALAADAuthority class]])
    {
        return [[MSALAADOauth2Provider alloc] initWithClientId:clientId tokenCache:tokenCache accountMetadataCache:accountMetadataCache];
    }
    else if ([authority isKindOfClass:[MSALCIAMAuthority class]])
    {
        return [[MSALCIAMOauth2Provider alloc] initWithClientId:clientId tokenCache:tokenCache accountMetadataCache:accountMetadataCache];
    }
    else if ([authority isKindOfClass:[MSALADFSAuthority class]])
    {
        MSIDFillAndLogError(error, MSIDErrorUnsupportedFunctionality, @"ADFS authority is not yet supported.", nil);
        return nil;
    }
    
    MSIDFillAndLogError(error, MSIDErrorUnsupportedFunctionality, @"Provided authority is not yet supported.", nil);
    return nil;
    
    // In the future, create base factory for everything else, but in future we might want to further separate this out
    // (e.g. ADFS, Google, Oauth2 etc...)
    // return [MSALOauth2Provider new];
}

@end
