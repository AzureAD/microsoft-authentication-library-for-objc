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

#import "MSALClaimsRequest+Internal.h"
#import "MSIDJsonSerializable.h"
#import "MSALIndividualClaimRequest+Internal.h"
#import "MSALIndividualClaimRequestAdditionalInfo.h"
#import "MSIDClaimsRequest.h"
#import "MSIDJsonSerializer.h"
#import "MSALErrorConverter.h"

@implementation MSALClaimsRequest

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        
        _msidClaimsRequest = [MSIDClaimsRequest new];
    }
    return self;
}

- (NSString *)description
{
    return [self.msidClaimsRequest description];
}

- (BOOL)requestClaim:(MSALIndividualClaimRequest *)request
           forTarget:(MSALClaimsRequestTarget)target
               error:(NSError **)error
{
    __auto_type msidTarget = [self msidTargetFromTarget:target];
    return [self.msidClaimsRequest requestClaim:request.msidIndividualClaimRequest
                                      forTarget:msidTarget
                                          error:error];
}

- (NSArray<MSALIndividualClaimRequest *> *)claimsRequestsForTarget:(MSALClaimsRequestTarget)target
{
    __auto_type msidTarget = [self msidTargetFromTarget:target];
    __auto_type msidClaimRequests = [self.msidClaimsRequest claimsRequestsForTarget:msidTarget];
    
    NSMutableArray<MSALIndividualClaimRequest *> *claimRequests = [NSMutableArray new];
    for (MSIDIndividualClaimRequest *r in msidClaimRequests)
    {
        __auto_type claimRequest = [[MSALIndividualClaimRequest alloc] initWithMsidIndividualClaimRequest:r];
        [claimRequests addObject:claimRequest];
    }
    
    return claimRequests;
}

- (BOOL)removeClaimRequestWithName:(NSString *)name
                            target:(MSALClaimsRequestTarget)target
                             error:(NSError **)error
{
    __auto_type msidTarget = [self msidTargetFromTarget:target];
    
    return [self.msidClaimsRequest removeClaimRequestWithName:name target:msidTarget error:error];
}

#pragma mark - MSALJsonDeserializable

- (instancetype)initWithJsonString:(NSString *)jsonString error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        
        NSError *msidError;
        _msidClaimsRequest = (MSIDClaimsRequest *)[self.jsonSerializer fromJsonString:jsonString
                                                                               ofType:MSIDClaimsRequest.class
                                                                              context:nil
                                                                                error:&msidError];
        
        if (msidError)
        {
            if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
            return nil;
        }
    }
    return self;
}

#pragma mark - MSALJsonStringSerializable

- (NSString *)jsonString
{
    NSError *msidError;
    NSString *result = [self.jsonSerializer toJsonString:self.msidClaimsRequest context:nil error:&msidError];
    
    if (msidError)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to serialize claims request to json string. Error %@", MSID_PII_LOG_MASKABLE(msidError));
    }
    
    return result;
}

#pragma mark - Private

- (void)commonInit
{
    MSIDJsonSerializer *jsonSerializer = [MSIDJsonSerializer new];
    jsonSerializer.normalizeJSON = NO;
    _jsonSerializer = jsonSerializer;
}

- (MSIDClaimsRequestTarget)msidTargetFromTarget:(MSALClaimsRequestTarget)target
{
    switch (target)
    {
        case MSALClaimsRequestTargetIdToken: return MSIDClaimsRequestTargetIdToken;
        case MSALClaimsRequestTargetAccessToken: return MSIDClaimsRequestTargetAccessToken;
        default: return MSIDClaimsRequestTargetIdToken;
    }
}

@end
