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

@class MSALUser;

@interface SampleMSALUtil : NSObject

+ (instancetype)sharedUtil;

/*!
    Called during app intialization to set up app-wide MSAL properties.
 */
+ (void)setup;


- (NSString *)currentUserIdentifer;

/*!
    Returns the current user for the application
 */
- (MSALUser *)currentUser:(NSError * __autoreleasing *)error;

/*!
    Signs in a user using MSAL.
 */
- (void)signInUser:(void (^)(MSALUser *user, NSString *token, NSError *error))signInBlock;

/*!
    Removes MSAL user state from the application.
 */

- (void)signOut;

/*!
    Acquires a token to use against graph for the current user
 */
- (void)acquireTokenSilentForCurrentUser:(NSArray<NSString *> *)scopes
                         completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

/*!
    Acquires a token using an interactive flow for the current user. Used if
    the library returns MSALErrorInteractionRequired.
 */
- (void)acquireTokenInteractiveForCurrentUser:(NSArray<NSString *> *)scopes
                              completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;


/*!
    Acquires a token first with the silent flow, falling back to a interactive call if required.
 */
- (void)acquireTokenForCurrentUser:(NSArray<NSString *> *)scopes
                   completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

@end
