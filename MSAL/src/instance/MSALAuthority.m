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

#import "MSALAuthority.h"

@implementation MSALAuthority

+ (void)resolveEndpoints:(NSString *)upn
      validatedAuthority:(NSURL *)unvalidatedAuthority
                validate:(BOOL)validate
                 context:(id<MSALRequestContext>)context
         completionBlock:(MSALAuthorityCompletion)completionBlock

{
    // TOOD: Authority discovery and validation
    (void)upn;
    (void)validate;
    (void)context;
    
    MSALAuthority *authority = [MSALAuthority new];
    authority.authorityType = AADAuthority;
    authority.canonicalAuthority = unvalidatedAuthority;
    authority.isTenantless = YES;
    authority.authorizationEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/authorize"];
    authority.tokenEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/token"];
    
    completionBlock(authority, nil);
}

+ (NSURL *)checkAuthorityString:(NSString *)authority
                          error:(NSError * __autoreleasing *)error
{
    REQUIRED_STRING_PARAMETER(authority, nil);
    
    NSURL *authorityUrl = [NSURL URLWithString:authority];
    CHECK_ERROR_RETURN_NIL(authorityUrl, nil, MSALErrorInvalidParameter, @"\"authority\" must be a valid URI");
    CHECK_ERROR_RETURN_NIL([authorityUrl.scheme isEqualToString:@"https"], nil, MSALErrorInvalidParameter, @"authority must use HTTPS");
    CHECK_ERROR_RETURN_NIL((authorityUrl.pathComponents.count > 1), nil, MSALErrorInvalidParameter, @"authority must specify a tenant or common");
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", authorityUrl.host, authorityUrl.pathComponents[1]]];
}

@end
