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

#import "MSALPkce.h"
#import "NSString+MSALHelperMethods.h"
#import "MSALCryptoHelper.h"

#define CHALLENGE_SHA256    @"S256"

static NSUInteger const s_kCodeVerifierByteSize = 32;

@implementation MSALPkce

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self->_codeVerifier = [self.class createCodeVerifier];
    self->_codeChallenge = [self.class createChallangeFromCodeVerifier:self->_codeVerifier];
    
    return self;
}

+ (NSString *)createCodeVerifier
{
    return [NSString randomUrlSafeStringOfSize:s_kCodeVerifierByteSize];
}

+ (NSString *)createChallangeFromCodeVerifier:(NSString *)codeVerifier
{
    return [NSString msalBase64UrlEncodeData:[MSALCryptoHelper msalSHA256fromString:codeVerifier]];
}

- (NSString *)codeChallengeMethod
{
    return CHALLENGE_SHA256;
}

@end
