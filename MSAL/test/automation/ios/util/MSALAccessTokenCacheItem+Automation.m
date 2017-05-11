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

#import "MSALAccessTokenCacheItem+Automation.h"
#import "MSALUser+Automation.h"

@implementation MSALAccessTokenCacheItem (Automation)

- (NSDictionary *)msalItemAsDictionary
{
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    [resultDict setValue:self.authority forKey:@"authority"];
    [resultDict setValue:self.rawIdToken forKey:@"id_token"];
    [resultDict setValue:self.uniqueId forKey:@"unique_id"];
    [resultDict setValue:self.accessToken forKey:@"access_token"];
    [resultDict setValue:self.tokenType forKey:@"token_type"];
    [resultDict setValue:[NSString stringWithFormat:@"%ld", (long)self.expiresOn.timeIntervalSince1970] forKey:@"expires_on"];
    [resultDict setValue:self.scope.msalToString forKey:@"scope"];
    [resultDict setValue:self.tenantId forKey:@"tenant_id"];
    [resultDict setValue:self.clientId forKey:@"client_id"];
    
    if (self.user)
    {
        [resultDict addEntriesFromDictionary:[self.user msalItemAsDictionary]];
    }
    
    return resultDict;
}

@end
