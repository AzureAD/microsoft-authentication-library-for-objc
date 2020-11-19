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

#import "MSALAuthenticationSchemePop+Internal.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSALHttpMethod.h"
#import "MSIDDevicePopManager.h"
#import "MSALAuthScheme.h"
#import "MSIDAccessToken.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAssymetricKeyPair.h"

static NSString *keyDelimiter = @" ";

@interface MSALAuthenticationSchemePop()

@property (nonatomic) MSALHttpMethod httpMethod;
@property (nonatomic) NSURL *requestUrl;
@property (nonatomic) NSString *nonce;
@property (nonatomic) NSDictionary *additionalParameters;

@end

@implementation MSALAuthenticationSchemePop

- (instancetype)initWithHttpMethod:(MSALHttpMethod)httpMethod
                        requestUrl:(NSURL *)requestUrl
                             nonce:(NSString *)nonce
              additionalParameters:(NSDictionary *)additionalParameters
{
    self = [super init];
    if (self)
    {
        _scheme = MSALAuthSchemePop;
        _httpMethod = httpMethod;
        _requestUrl = requestUrl;
        _nonce = nonce ? nonce : [[NSUUID new] UUIDString];
        _additionalParameters = additionalParameters ? additionalParameters : [NSDictionary new];
    }

    return self;
}

- (NSString *)authenticationScheme
{
    return MSALParameterStringForAuthScheme(self.scheme);
}

#pragma mark - MSALAuthenticationSchemeProtocolInternal

- (MSIDAuthenticationScheme *)createMSIDAuthenticationSchemeWithParams:(nullable NSDictionary *)params
{
    return [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:params];
}

- (NSDictionary *)getSchemeParameters:(MSIDDevicePopManager *)popManager
{
    NSMutableDictionary *schemeParams = [NSMutableDictionary new];
    NSString *requestConf = popManager.keyPair.jsonWebKey;
    if (requestConf)
    {
        [schemeParams setObject:MSALParameterStringForAuthScheme(self.scheme) forKey:MSID_OAUTH2_TOKEN_TYPE];
        [schemeParams setObject:requestConf forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to append public key jwk to request headers.");
    }
    
    return schemeParams;
}

/// <summary>
/// Proof-of-Possession Key for JWTs
/// </summary>
/// <remarks>
/// This SDK will use RFC7800
/// See https://tools.ietf.org/html/rfc7800 Section 3.2
/// </remarks>

- (nullable NSString *)getClientAccessToken:(MSIDAccessToken *)accessToken popManager:(nullable MSIDDevicePopManager *)popManager error:(NSError **)error
{
    NSString *signedAccessToken = [popManager createSignedAccessToken:accessToken.accessToken
                                                           httpMethod:MSALParameterStringForHttpMethod(self.httpMethod)
                                                           requestUrl:self.requestUrl.absoluteString
                                                                nonce:self.nonce
                                                                error:error];
    
    if (!signedAccessToken)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to sign access token.");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to sign access token.", nil, nil, nil, nil, nil, YES);
        }
        
        return nil;
    }
    
    return signedAccessToken;
}

- (NSString *)getAuthorizationHeader:(NSString *)accessToken
{
    return [NSString stringWithFormat:@"%@%@%@", self.authenticationScheme, keyDelimiter, accessToken];
}

@end
