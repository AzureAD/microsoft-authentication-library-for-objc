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

#import "MSALIndividualClaimRequest+Internal.h"
#import "MSIDIndividualClaimRequest.h"
#import "MSALIndividualClaimRequestAdditionalInfo+Internal.h"
#import "MSIDIndividualClaimRequestAdditionalInfo.h"

@implementation MSALIndividualClaimRequest

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        _msidIndividualClaimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:name];
    }
    return self;
}

- (NSString *)description
{
    return [self.msidIndividualClaimRequest description];
}

- (instancetype)initWithMsidIndividualClaimRequest:(MSIDIndividualClaimRequest *)msidIndividualClaimRequest
{
    self = [super init];
    if (self)
    {
        _msidIndividualClaimRequest = msidIndividualClaimRequest;
    }
    return self;
}

- (void)setName:(NSString *)name
{
    self.msidIndividualClaimRequest.name = name;
}

- (NSString *)name
{
    return self.msidIndividualClaimRequest.name;
}

- (void)setAdditionalInfo:(MSALIndividualClaimRequestAdditionalInfo *)additionalInfo
{
    self.msidIndividualClaimRequest.additionalInfo = additionalInfo.msidAdditionalInfo;
}

- (MSALIndividualClaimRequestAdditionalInfo *)additionalInfo
{
    MSALIndividualClaimRequestAdditionalInfo *additionalInfo = [[MSALIndividualClaimRequestAdditionalInfo alloc] initWithMsidIndividualClaimRequestAdditionalInfo:self.msidIndividualClaimRequest.additionalInfo];
    return additionalInfo;
}

@end
