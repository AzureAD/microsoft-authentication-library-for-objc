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

NSString* const ID_TOKEN_ISSUER = @"iss";
NSString* const ID_TOKEN_OBJECT_ID = @"oid";
NSString* const ID_TOKEN_SUBJECT = @"sub";
NSString* const ID_TOKEN_TENANT_ID = @"tid";
NSString* const ID_TOKEN_VERSION = @"ver";
NSString* const ID_TOKEN_PERFERRED_USERNAME = @"preferred_username";
NSString* const ID_TOKEN_NAME = @"name";
NSString* const ID_TOKEN_HOME_OBJECT_ID = @"home_oid";

@implementation MSALIdToken

MSAL_JSON_ACCESSOR(ID_TOKEN_ISSUER, issuer)
MSAL_JSON_ACCESSOR(ID_TOKEN_OBJECT_ID, objectId)
MSAL_JSON_ACCESSOR(ID_TOKEN_SUBJECT, subject)
MSAL_JSON_ACCESSOR(ID_TOKEN_TENANT_ID, tenantId)
MSAL_JSON_ACCESSOR(ID_TOKEN_VERSION, version)
MSAL_JSON_ACCESSOR(ID_TOKEN_PERFERRED_USERNAME, preferredUsername)
MSAL_JSON_ACCESSOR(ID_TOKEN_NAME, name)
MSAL_JSON_ACCESSOR(ID_TOKEN_HOME_OBJECT_ID, homeObjectId)

- (id)initWithRawIdToken:(NSString *)rawIdToken
{
    if ([NSString msalIsStringNilOrBlank:rawIdToken])
    {
        return nil;
    }
    
    NSArray* parts = [rawIdToken componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
    if (parts.count != 3)
    {
        LOG_WARN(nil, @"Id token is invalid.");
        return nil;
    }
    
    NSError *error = nil;
    if (!(self = [super initWithData:parts[1] error:&error]))
    {
        if (error)
        {
            LOG_WARN(nil, @"Id token is invalid. Error: %@", error.localizedDescription);
        }
        return nil;
    }
    
    return self;
}

@end