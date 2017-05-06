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

#import "MSALTestIdTokenUtil.h"
#import "NSDictionary+MSALTestUtil.h"

@implementation MSALTestIdTokenUtil

+ (NSString *)defaultName
{
    return @"User";
}

+ (NSString *)defaultUsername
{
    return @"user@contoso.com";
}

+ (NSString *)defaultTenantId
{
    return @"1234-5678-90abcdefg";
}

+ (NSString *)defaultUniqueId
{
    return @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97";
}

+ (NSString *)defaultIdToken
{
    return [self idTokenWithName:[self defaultName] preferredUsername:[self defaultUsername]];
}

+ (NSString *)idTokenWithName:(NSString *)name
            preferredUsername:(NSString *)preferredUsername
{
    return [self idTokenWithName:name preferredUsername:preferredUsername tenantId:nil];
}

+ (NSString *)idTokenWithName:(NSString *)name
            preferredUsername:(NSString *)preferredUsername
                     tenantId:(NSString *)tid
{
    NSString *idTokenp1 = [@{ @"typ": @"JWT", @"alg": @"RS256", @"kid": @"_UgqXG_tMLduSJ1T8caHxU7cOtc"} base64UrlJson];
    NSString *idTokenp2 = [@{ @"iss" : @"issuer",
                              @"name" : name,
                              @"preferred_username" : preferredUsername,
                              @"tid" : tid ? tid : [self defaultTenantId],
                              @"oid" : [self defaultUniqueId]} base64UrlJson];
    return [NSString stringWithFormat:@"%@.%@.%@", idTokenp1, idTokenp2, idTokenp1];
}

@end
