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

#import <Foundation/Foundation.h>
#import "MSIDTestAccountsProvider.h"
#import <MSAL/MSAL.h>

extern NSString *const MSAL_TEST_DEFAULT_NON_CONVERGED_REDIRECT_URI;

@interface MSALTestRequest : NSObject

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *scopes;
@property (nonatomic, strong) NSArray *expectedResultScopes;
@property (nonatomic, strong) NSString *redirectUri;
@property (nonatomic, strong) NSString *authority;
@property (nonatomic, strong) NSString *cacheAuthority;
@property (nonatomic, strong) NSString *uiBehavior;
@property (nonatomic, strong) NSString *accountIdentifier;
@property (nonatomic, strong) NSString *loginHint;
@property (nonatomic, strong) NSString *claims;
@property (nonatomic, strong) MSIDTestAccount *testAccount;
@property (nonatomic) BOOL usePassedWebView;
@property (nonatomic) MSALWebviewType webViewType;
@property (nonatomic) BOOL validateAuthority;
@property (nonatomic, strong) NSString *b2cProvider;
@property (nonatomic, strong) NSDictionary *additionalParameters;

+ (MSALTestRequest *)convergedAppRequest;
+ (MSALTestRequest *)nonConvergedAppRequest;
+ (MSALTestRequest *)b2CRequestWithSigninPolicyWithAccount:(MSIDTestAccount *)account;
+ (MSALTestRequest *)b2CRequestWithProfilePolicyWithAccount:(MSIDTestAccount *)account;
- (BOOL)usesEmbeddedWebView;
+ (MSALTestRequest *)fociRequestWithOfficeApp;
+ (MSALTestRequest *)fociRequestWithOnedriveApp;

@end
