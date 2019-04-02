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

#import <Foundation/Foundation.h>
#import "MSALJsonStringSerializable.h"

@class MSALIndividualClaimRequest;

/*!
 Claims targets. Currently we support only "access_token" and "id_token".
 "userinfo" is not supported.
 */
typedef NS_ENUM(NSUInteger, MSALClaimsRequestTarget)
{
    MSALClaimsRequestTargetIdToken,
    MSALClaimsRequestTargetAccessToken
};

NS_ASSUME_NONNULL_BEGIN

/*!
 Represents the claims request parameter as an object.
 See more info here: https://openid.net/specs/openid-connect-core-1_0-final.html#ClaimsParameter
 */
@interface MSALClaimsRequest : NSObject <MSALJsonStringSerializable>

/*!
 Adds a request for a specific claim to be included in the target via the claims request parameter.
 If claim request alredy exists, provided claim request takes its place.
 @param request Individual claim request.
 @param target Target of individual claim.
 */
- (void)requestClaim:(MSALIndividualClaimRequest *)request forTarget:(MSALClaimsRequestTarget)target;

/*!
 Return the list of requested claims for the target.
 @param target Target of requested claims.
 */
- (NSArray<MSALIndividualClaimRequest *> *)claimRequestsForTarget:(MSALClaimsRequestTarget)target;

/*!
 Remove requested claims for the target.
 @param name of requested claim.
 @param target Target of individual claim.
 */
- (void)removeClaimRequestWithName:(NSString *)name target:(MSALClaimsRequestTarget)target;

@end

NS_ASSUME_NONNULL_END
