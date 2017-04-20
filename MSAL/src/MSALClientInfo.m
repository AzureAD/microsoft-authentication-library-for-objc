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

#import "MSALClientInfo.h"
#import "MSALOAuth2Constants.h"

@implementation MSALClientInfo

MSAL_JSON_ACCESSOR(OAUTH2_UNIQUE_IDENTIFIER, uid)
MSAL_JSON_ACCESSOR(OAUTH2_UNIQUE_TENANT_IDENTIFIER, utid)

- (id)initWithRawClientInfo:(NSString *)rawClientInfo
                      error:(NSError *__autoreleasing *)error
{
    NSData *decoded =  [[rawClientInfo msalBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    if (!(self = [super initWithData:decoded error:error]))
    {
        return nil;
    }
    
    return self;
}

- (NSString *)userIdentifier
{
    return [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
}

@end
