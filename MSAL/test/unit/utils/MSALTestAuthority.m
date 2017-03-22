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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestAuthority.h"

@implementation MSALTestAuthority

+ (MSALTestAuthority *)AADAuthority:(NSURL *)unvalidatedAuthority
{
    MSALTestAuthority *authority = [MSALTestAuthority new];
    authority.authorityType = AADAuthority;
    authority.canonicalAuthority = unvalidatedAuthority;
    authority.isTenantless = YES;
    authority.authorizationEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/authorize"];
    authority.tokenEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/token"];
    return authority;
}

+ (MSALTestAuthority *)B2CAuthority:(NSURL *)unvalidatedAuthority
{
    MSALTestAuthority *authority = [self AADAuthority:unvalidatedAuthority];
    authority.isTenantless = NO;
    authority.authorityType = B2CAuthority;
    return authority;
}

+ (MSALTestAuthority *)ADFSAuthority:(NSURL *)unvalidatedAuthority
{
    MSALTestAuthority *authority = [MSALTestAuthority new];
    authority.authorityType = ADFSAuthority;
    authority.canonicalAuthority = unvalidatedAuthority;
    authority.isTenantless = NO;
    authority.authorizationEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/authorize"];
    authority.tokenEndpoint = [unvalidatedAuthority URLByAppendingPathComponent:@"oauth2/v2.0/token"];
    return authority;
}

@end
