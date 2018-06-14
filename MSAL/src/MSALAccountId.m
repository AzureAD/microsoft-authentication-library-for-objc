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

#import "MSALAccountId+Internal.h"

@implementation MSALAccountId

- (instancetype)initWithHomeAccountIdentifier:(NSString *)identifier
                                          uid:(NSString *)uid
                                         utid:(NSString *)utid
{
    self = [super init];

    if (self)
    {
        _identifier = identifier;
        _objectId = uid;
        _tenantId = utid;
    }

    return self;
}

- (instancetype)initWithLocalAccountIdentifier:(NSString *)identifier
                                      objectId:(NSString *)objectId
                                      tenantId:(NSString *)tenantId
{
    self = [super init];

    if (self)
    {
        _identifier = identifier;
        _objectId = objectId;
        _tenantId = tenantId;
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    MSALAccountId *accountId = [[MSALAccountId allocWithZone:zone] init];
    accountId->_identifier = _identifier;
    accountId->_objectId = _objectId;
    accountId->_tenantId = _tenantId;
    return accountId;
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.identifier.hash;
    hash = hash * 31 + self.objectId.hash;
    hash = hash * 31 + self.tenantId.hash;
    return hash;
}

@end
