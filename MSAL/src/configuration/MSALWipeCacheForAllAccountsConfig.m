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

#import "MSALWipeCacheForAllAccountsConfig.h"

@implementation MSALWipeCacheForAllAccountsConfig

+ (NSDictionary<NSString *, NSDictionary *> *) additionalPartnerLocations
{
#if TARGET_OS_IPHONE
    return @{};
#else
    return @{
        @"Microsoft Office" : @{(id)kSecAttrAccount : @"adalcache",
                                  (id)kSecAttrLabel : @"com.microsoft.adalcache",
                                (id)kSecAttrService : @"AdalCache"},

        @"Microsoft Teams" : @{(id)kSecAttrAccount : @"Microsoft Teams Identities Cache",
                                 (id)kSecAttrLabel : @"Microsoft Teams Identities Cache",
                               (id)kSecAttrService : @"Microsoft Teams Identities Cache"},
        
        @"Visual Studio for Mac, Azure CLI & PowerShell" : @{(id)kSecAttrAccount : @"MSALCache",
                                                               (id)kSecAttrLabel : @"Microsoft.Developer.IdentityService",
                                                             (id)kSecAttrService : @"Microsoft.Developer.IdentityService"},
        
        @"Visual Studio Code" : @{(id)kSecAttrAccount : @"microsoft.login",
                                    (id)kSecAttrLabel : @"vscodevscode.microsoft-authentication",
                                  (id)kSecAttrService : @"vscodevscode.microsoft-authentication"},
        
        @"Microsoft To-Do AAD" : @{(id)kSecAttrAccount : @"com.microsoft.projectcheshire.keychain",
                                    (id)kSecAttrLabel : @"com.microsoft.to-do-mac.AADTokenCache",
                                  (id)kSecAttrService : @"com.microsoft.to-do-mac.AADTokenCache"},

        @"Microsoft To-Do MSA" : @{(id)kSecAttrAccount : @"com.microsoft.projectcheshire.keychain",
                                    (id)kSecAttrLabel : @"com.microsoft.todo.MSAUserKeychain",
                                  (id)kSecAttrService : @"com.microsoft.todo.MSAUserKeychain"}
    };
#endif
}

@end
