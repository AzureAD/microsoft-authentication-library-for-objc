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

#import "MSALErrorConverter.h"
#import "MSALError_Internal.h"

static NSDictionary *s_errorDomainMapping;
static NSDictionary *s_errorCodeMapping;

@implementation MSALErrorConverter

+ (void)initialize
{
    s_errorDomainMapping = @{
                             MSIDErrorDomain : MSALErrorDomain
                             };
    
    s_errorCodeMapping = @{
                           //sample format is like @"MSIDErrorDomain|-10000":@"-20000"
                           };
}

+ (NSError *)MSALErrorFromMSIDError:(NSError *)msidError
{
    if (!msidError)
    {
        return nil;
    }
    
    //Map domain
    NSString *domain = msidError.domain;
    if (domain && s_errorDomainMapping[domain])
    {
        domain = s_errorDomainMapping[domain];
    }
    
    //Map errorCode. Note that errorCode must be mapped together with domain
    NSInteger errorCode = msidError.code;
    NSString *mapKey = [NSString stringWithFormat:@"%@|%ld", msidError.domain, (long)errorCode];
    NSString *mapValue = s_errorCodeMapping[mapKey];
    if (![NSString msidIsStringNilOrBlank:mapValue])
    {
        errorCode = [mapValue integerValue];
    }
    
    NSMutableDictionary *userInfo = nil;
    if (msidError.userInfo[MSIDHTTPHeadersKey] || msidError.userInfo[MSIDHTTPResponseCodeKey])
    {
        userInfo = [NSMutableDictionary new];
        [userInfo setValue:msidError.userInfo[MSIDHTTPHeadersKey] forKey:MSALHTTPHeadersKey];
        [userInfo setValue:msidError.userInfo[MSIDHTTPResponseCodeKey] forKey:MSALHTTPResponseCodeKey];
    }
    
    return MSALCreateError(domain,
                           errorCode,
                           msidError.userInfo[MSIDErrorDescriptionKey],
                           msidError.userInfo[MSIDOAuthErrorKey],
                           msidError.userInfo[MSIDOAuthSubErrorKey],
                           msidError.userInfo[NSUnderlyingErrorKey],
                           userInfo);
    
}

@end
