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
#import "MSALJsonSerializable.h"
#import "MSALJsonDeserializable.h"

@class MSALIndividualClaimRequest;

/**
 Target for the claims request.
 Only "access_token" and "id_token" are supported.
 "userinfo" is not supported.
 */
typedef NS_ENUM(NSUInteger, MSALClaimsRequestTarget)
{
    /**
        Request specific claims for the id_token.
     */
    MSALClaimsRequestTargetIdToken,
    
    /**
       Request specific claims for the access_token.
    */
    MSALClaimsRequestTargetAccessToken
};

NS_ASSUME_NONNULL_BEGIN

/**
 OpenID Connect allows you to optionally request the return of individual claims from the UserInfo Endpoint and/or in the ID Token. A claims request is represented as a JSON object that contains a list of requested claims.

 The Microsoft Authentication Library (MSAL) for iOS and macOS allows requesting specific claims in both interactive and silent token acquisition scenarios. It does so through the claimsRequest parameter.

 There are multiple scenarios where this is needed. For example:

 - Requesting claims outside of the standard set for your application.
 - Requesting specific combinations of the standard claims that cannot be specified using scopes for your application. For example, if an access token gets rejected because of missing claims, the application can request the missing claims using MSAL.
 
 See more info here: https://openid.net/specs/openid-connect-core-1_0-final.html#ClaimsParameter
 
 Example of Claims Request serialized to json:
 
  <pre>
 {
    "access_token":
    {
        "capolids": {"essential":true, "values":["00000000-0000-0000-0000-000000000001"]}
    },
    "id_token":
    {
     "auth_time": {"essential": true},
     "acr": {"values": ["urn:mace:incommon:iap:silver"]}
    }
 }
 </pre>
 
 @note MSALClaimsRequest is NOT thread safe.
 @note MSAL bypasses the access token cache whenever a claims request is specified. It's important to only provide claimsRequest parameter when additional claims are needed (as opposed to always providing same claimsRequest parameter in each MSAL API call).
 
 */
@interface MSALClaimsRequest : NSObject <MSALJsonSerializable, MSALJsonDeserializable>

#pragma mark - Constructing MSALClaimsRequest

/**
 Adds a request for a specific claim to be included in the target via the claims request parameter.
 If claim request alredy exists, provided claim request takes its place.
 @param request Individual claim request.
 @param target Target of individual claim.
 @param error The error that occurred during requesting the claim.
 @return YES if operation was successful, NO otherwise.
 */
- (BOOL)requestClaim:(MSALIndividualClaimRequest *)request
           forTarget:(MSALClaimsRequestTarget)target
               error:(NSError * _Nullable * _Nullable)error;

/**
 Remove requested claims for the target.
 @param name of requested claim.
 @param target Target of individual claim.
 @param error The error that occurred during removing the claim request.
 @return YES if operation was successful, NO otherwise.
 */
- (BOOL)removeClaimRequestWithName:(NSString *)name
                            target:(MSALClaimsRequestTarget)target
                             error:(NSError * _Nullable * _Nullable)error;

#pragma mark - Read components of MSALClaimsRequest

/**
 Return the array of requested claims for the target.
 @param target Target of requested claims.
 @return Array of individual claim requests.
 */
- (nullable NSArray<MSALIndividualClaimRequest *> *)claimsRequestsForTarget:(MSALClaimsRequestTarget)target;

@end

NS_ASSUME_NONNULL_END
