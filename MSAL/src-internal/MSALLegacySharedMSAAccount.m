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

#import "MSALLegacySharedMSAAccount.h"
#import "MSIDJsonObject.h"
#import "MSIDAADAuthority.h"
#import "MSIDConstants.h"
#import "MSIDAccountIdentifier.h"

static NSString *kMSAAccountType = @"MSA";

@interface MSALLegacySharedMSAAccount()

@property (nonatomic) MSIDAADAuthority *authority;

@end

static NSString *kDefaultCacheAuthority = @"https://login.windows.net/common";

@implementation MSALLegacySharedMSAAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super initWithJSONDictionary:jsonDictionary error:error];
    
    if (self)
    {
        if (![self.accountType isEqualToString:kMSAAccountType])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account type", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:kDefaultCacheAuthority] rawTenant:nil context:nil error:error];

        _environment = _authority.environment;
        NSString *cid = [jsonDictionary msidStringObjectForKey:@"cid"];
        NSString *uid = [[self class] cidAsGUID:cid];
        
        if ([NSString msidIsStringNilOrBlank:uid])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected identifier found for MSA account", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _identifier = [MSIDAccountIdentifier homeAccountIdentifierFromUid:uid utid:MSID_DEFAULT_MSA_TENANTID];
        _username = [jsonDictionary msidStringObjectForKey:@"email"];
        
        _accountClaims = @{@"tid": MSID_DEFAULT_MSA_TENANTID,
                           @"oid": _identifier,
                           @"preferred_username": _username};
    }
    
    return self;
}

+ (NSString *)cidAsGUID:(NSString *)cid
{
    if (cid.length != 16)
    {
        return nil;
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:[[self guidDataFromString:cid] bytes]];
    return uuid.UUIDString.lowercaseString;
}

+ (NSData *)guidDataFromString:(NSString *)cidString
{
    NSMutableData *result = [[NSMutableData alloc] initWithLength:16];
    unsigned char b;
    char chars[3] = {'\0','\0','\0'};
    for (int i=0; i < [cidString length]/2; i++)
    {
        chars[0] = [cidString characterAtIndex:i*2];
        chars[1] = [cidString characterAtIndex:i*2+1];
        b = strtol(chars, NULL, 16);
        
        if ([result length] > 8+i)
        {
            [result replaceBytesInRange:NSMakeRange(8+i, 1) withBytes:&b length:1];
        }
    }
    
    return result;
}

@end
