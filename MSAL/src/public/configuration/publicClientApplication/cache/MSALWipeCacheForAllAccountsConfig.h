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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/**
 MSAL configuration interface responsible for keeping a list of additional cache locations for partner caches to be wiped.
 */
@interface MSALWipeCacheForAllAccountsConfig : NSObject

/**
    List of additional locations for partner caches to be wiped (e.g. Teams, VisualStudio etc). Wipe operation should wipe out all those additional locations.
    The key is "display identifier" of the location (e.g. Teams cache)
    The value is the precise identifiers like kSecAttrAccount, kSecAttrService etc.
 */
+ (NSDictionary<NSString *, NSDictionary *> *) additionalPartnerLocations;

@end

NS_ASSUME_NONNULL_END
