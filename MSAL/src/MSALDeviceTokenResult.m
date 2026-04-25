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

#import "MSALDeviceTokenResult.h"
#import "MSIDAuthority.h"
#import "MSALAADAuthority.h"

@implementation MSALDeviceTokenResult

- (nonnull instancetype)initWithAccessToken:(nonnull NSString *)accessToken
                          deviceInformation:(nullable NSString *)deviceInformation
                                  expiresOn:(nullable NSDate *)expiresOn
                                     scopes:(nonnull NSArray<NSString *> *)scopes
                                  authority:(nullable MSALAuthority *)authority
{
    self = [super init];
    if (self)
    {
        _accessToken = accessToken;
        _deviceInformation = deviceInformation;
        _expiresOn = expiresOn;
        _scopes = scopes;
        _authority = authority;
    }
    return self;
}

+ (MSALDeviceTokenResult *)resultForDeviceTokenResult:(MSIDTokenResult *)tokenResult
                                                error:(NSError **)error
{
    if (!tokenResult)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Nil token result provided", nil);
        return nil;
    }
    
    if (tokenResult.refreshToken)
    {
        MSIDFillAndLogError(error, MSIDErrorServerInvalidResponse, @"Unexpected refresh token found in device token result", nil);
        return nil;
    }
    
    if (![NSString msidIsStringNilOrBlank:tokenResult.rawIdToken])
    {
        MSIDFillAndLogError(error, MSIDErrorServerInvalidResponse, @"Unexpected id token found in device token result", nil);
        return nil;
    }
    
    NSString *resultAccessToken = @"";
    NSArray *resultScopes = @[];
    
    if (![NSString msidIsStringNilOrBlank:tokenResult.accessToken.accessToken])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Parsing result access token");
        resultAccessToken = tokenResult.accessToken.accessToken;
        resultScopes = [tokenResult.accessToken.scopes array];
    }
    else
    {
        MSIDFillAndLogError(error, MSIDErrorServerInvalidResponse, @"Access token missing in device token result", nil);
        return nil;
    }
    
    NSError *authorityError;
    MSALAADAuthority *aadAuthority = [[MSALAADAuthority alloc] initWithURL:tokenResult.authority.url error:&authorityError];
    
    if (!aadAuthority)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Invalid authority, error %@", MSID_PII_LOG_MASKABLE(authorityError));
        
        if (error) *error = authorityError;
        
        return nil;
    }
    
    NSString *deviceInformationJwt = tokenResult.tokenResponse.additionalServerInfo[@"device_info"];
    
    return [[MSALDeviceTokenResult alloc] initWithAccessToken:resultAccessToken
                                            deviceInformation:deviceInformationJwt
                                                    expiresOn:tokenResult.accessToken.expiresOn
                                                       scopes:resultScopes
                                                    authority:aadAuthority];
}

@end
