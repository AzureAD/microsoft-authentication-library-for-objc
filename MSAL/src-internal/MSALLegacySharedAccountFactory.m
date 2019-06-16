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

#import "MSALLegacySharedAccountFactory.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSALLegacySharedADALAccount.h"
#import "MSALLegacySharedMSAAccount.h"
#import "MSIDConstants.h"

@implementation MSALLegacySharedAccountFactory

+ (MSALLegacySharedAccount *)accountWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    NSString *accountType = [jsonDictionary msidStringObjectForKey:@"type"];
    
    if (!accountType)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"No account type available");
        return nil;
    }
    
    if ([accountType isEqualToString:@"ADAL"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Initializing ADAL account type");
        return [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:error];
    }
    else if ([accountType isEqualToString:@"MSA"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Initializing MSA account type");
        return [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:error];
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Unknown account type found %@", accountType);
    return nil;
}

+ (nullable MSALLegacySharedAccount *)accountsWithMSALAccount:(id<MSALAccount>)account
                                                       claims:(NSDictionary *)claims
                                              applicationName:(NSString *)applicationName
                                                        error:(NSError **)error
{
    if ([claims[@"tid"] isEqualToString:MSID_DEFAULT_MSA_TENANTID]) // TODO: check by uid instead?
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Initializing MSA account type");
        return [[MSALLegacySharedMSAAccount alloc] initWithMSALAccount:account accountClaims:claims applicationName:applicationName error:error];
    }
    else if (![NSString msidIsStringNilOrBlank:claims[@"oid"]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Initializing MSA account type");
        return [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:account accountClaims:claims applicationName:applicationName error:error];
    }
    
    return nil;
}

@end
