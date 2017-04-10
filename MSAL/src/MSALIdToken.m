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

#import "MSALIdToken.h"

#define ID_TOKEN_ISSUER              @"iss"
#define ID_TOKEN_OBJECT_ID           @"oid"
#define ID_TOKEN_SUBJECT             @"sub"
#define ID_TOKEN_TENANT_ID           @"tid"
#define ID_TOKEN_VERSION             @"ver"
#define ID_TOKEN_PERFERRED_USERNAME  @"preferred_username"
#define ID_TOKEN_NAME                @"name"
#define ID_TOKEN_HOME_OBJECT_ID      @"home_oid"

@implementation MSALIdToken

MSAL_JSON_ACCESSOR(ID_TOKEN_ISSUER, issuer)
MSAL_JSON_ACCESSOR(ID_TOKEN_OBJECT_ID, objectId)
MSAL_JSON_ACCESSOR(ID_TOKEN_SUBJECT, subject)
MSAL_JSON_ACCESSOR(ID_TOKEN_TENANT_ID, tenantId)
MSAL_JSON_ACCESSOR(ID_TOKEN_VERSION, version)
MSAL_JSON_ACCESSOR(ID_TOKEN_PERFERRED_USERNAME, preferredUsername)
MSAL_JSON_ACCESSOR(ID_TOKEN_NAME, name)
MSAL_JSON_ACCESSOR(ID_TOKEN_HOME_OBJECT_ID, homeObjectId)

- (id)initWithRawIdToken:(NSString *)rawIdTokenString
{
    if ([NSString msalIsStringNilOrBlank:rawIdTokenString])
    {
        return nil;
    }
    
    NSArray* parts = [rawIdTokenString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
    if (parts.count != 3)
    {
        LOG_WARN(nil, @"Id token is invalid.");
        return nil;
    }
    
    NSData *decoded =  [[parts[1] msalBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    if (!(self = [super initWithData:decoded error:&error]))
    {
        if (error)
        {
            LOG_WARN(nil, @"Id token is invalid. Error: %@", error.localizedDescription);
        }
        return nil;
    }
    
    return self;
}

- (NSString *)uniqueId
{
    return self.objectId ? self.objectId : self.subject;
}

@end
