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

#import "MSALAccountEnumerationParameters.h"

@interface MSALAccountEnumerationParameters()

@property (nonatomic, readwrite, nullable) NSString *identifier;
@property (nonatomic, readwrite, nullable) NSString *tenantProfileIdentifier;
@property (nonatomic, readwrite, nullable) NSString *username;

@end

@implementation MSALAccountEnumerationParameters

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _returnOnlySignedInAccounts = YES;
    }
    
    return self;
}

- (instancetype)initWithIdentifier:(nonnull NSString *)accountIdentifier
{
    self = [super init];
    
    if (self)
    {
        _identifier = accountIdentifier;
        _returnOnlySignedInAccounts = YES;
    }
    
    return self;
}

- (instancetype)initWithIdentifier:(nullable NSString *)accountIdentifier
                          username:(nonnull NSString *)username
{
    self = [super init];
    
    if (self)
    {
        _identifier = accountIdentifier;
        _username = username;
        _returnOnlySignedInAccounts = YES;
    }
    
    return self;
}

- (instancetype)initWithTenantProfileIdentifier:(nonnull NSString *)tenantProfileIdentifier
{
    self = [super init];
    
    if (self)
    {
        _tenantProfileIdentifier = tenantProfileIdentifier;
        _returnOnlySignedInAccounts = YES;
    }
    
    return self;
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"Account identifier %@, username %@, tenant profile identifier %@, return only signed in accounts %d", self.identifier, self.username, self.tenantProfileIdentifier, self.returnOnlySignedInAccounts];
}

@end
