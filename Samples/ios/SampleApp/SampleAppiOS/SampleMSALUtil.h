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

#import <Foundation/Foundation.h>

@class MSALAccount;

@interface SampleMSALUtil : NSObject

+ (instancetype)sharedUtil;

/*!
    Called during app intialization to set up app-wide MSAL properties.
 */
+ (void)setup;


- (NSString *)currentAccountIdentifer;

/*!
    Returns the current account for the application
 */
- (MSALAccount *)currentAccount:(NSError * __autoreleasing *)error;

/*!
    Signs in an account using MSAL.
 */
- (void)signInAccount:(void (^)(MSALAccount *account, NSString *token, NSError *error))signInBlock;

/*!
    Removes MSAL account state from the application.
 */

- (void)signOut;

/*!
    Acquires a token to use against graph for the current account
 */
- (void)acquireTokenSilentForCurrentAccount:(NSArray<NSString *> *)scopes
                            completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

/*!
    Acquires a token using an interactive flow for the current account. Used if
    the library returns MSALErrorInteractionRequired.
 */
- (void)acquireTokenInteractiveForCurrentAccount:(NSArray<NSString *> *)scopes
                                 completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;


/*!
    Acquires a token first with the silent flow, falling back to a interactive call if required.
 */
- (void)acquireTokenForCurrentAccount:(NSArray<NSString *> *)scopes
                      completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

@end
