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

#import "MSALLegacySharedADALAccount.h"
#import "MSIDAADAuthority.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDAccountIdentifier.h"

static NSString *kADALAccountType = @"ADAL";

@interface MSALLegacySharedADALAccount()

@property (nonatomic) MSIDAADAuthority *authority;

@end

@implementation MSALLegacySharedADALAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super initWithJSONDictionary:jsonDictionary error:error];
    
    if (self)
    {
        if (![self.accountType isEqualToString:kADALAccountType])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account type", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        NSString *authEndpoint = [jsonDictionary msidStringObjectForKey:@"authEndpointUrl"];
        _authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:authEndpoint] rawTenant:nil context:nil error:error];
        
        if (!_authority)
        {
            return nil;
        }
        
        _environment = _authority.environment;
        
        NSString *objectId = [jsonDictionary msidStringObjectForKey:@"oid"];
        NSString *tenantId = [jsonDictionary msidStringObjectForKey:@"tenantId"];
        
        if (_authority.tenant.type == MSIDAADTenantTypeCommon)
        {
            _identifier = [MSIDAccountIdentifier homeAccountIdentifierFromUid:objectId utid:tenantId];
        }
        
        NSMutableDictionary *claims = [NSMutableDictionary new];
        
        if (![NSString msidIsStringNilOrBlank:objectId])
        {
            claims[@"oid"] = objectId;
        }
        
        if (![NSString msidIsStringNilOrBlank:tenantId])
        {
            claims[@"tid"] = tenantId;
        }
        
        NSString *displayName = [jsonDictionary msidStringObjectForKey:@"displayName"];
        
        if (![NSString msidIsStringNilOrBlank:displayName])
        {
            claims[@"name"] = displayName;
        }
        
        _username = [jsonDictionary msidStringObjectForKey:@"username"];
        
        if (![NSString msidIsStringNilOrBlank:_username])
        {
            claims[@"upn"] = _username;
        }
        
        _accountClaims = claims;
    }
    
    return self;
}

@end
