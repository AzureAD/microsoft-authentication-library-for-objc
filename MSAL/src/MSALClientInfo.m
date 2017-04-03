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

MSAL_JSON_ACCESSOR(OAUTH2_UNIQUE_IDENTIFIER, uniqueIdentifier)
MSAL_JSON_ACCESSOR(OAUTH2_UNIQUE_TENANT_IDENTIFIER, uniqueTenantIdentifier)

- (id)initWithRawClientInfo:(NSString *)rawClientInfo
{
    if ([NSString msalIsStringNilOrBlank:rawClientInfo])
    {
        LOG_WARN(nil, @"client_info is empty.");
        LOG_WARN_PII(nil, @"client_info is empty.");
        return nil;
    }
    
    NSData *decoded =  [[rawClientInfo msalBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    if (!(self = [super initWithData:decoded error:&error]))
    {
        if (error)
        {
            LOG_WARN(nil, @"client_info is invalid. Error: %@", error.localizedDescription);
            LOG_WARN_PII(nil, @"client_info is invalid. Error: %@", error.localizedDescription);
        }
        return nil;
    }
    
    return self;
}

@end