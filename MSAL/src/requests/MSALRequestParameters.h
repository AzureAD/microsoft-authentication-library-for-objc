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
#import "MSALUIBehavior.h"
#import "MSALTelemetryApiId.h"
#import "MSALRequestContext.h"
#import "MSIDRequestContext.h"

@class MSALAuthority;
@class MSALAccount;
@class MSIDConfiguration;
@class MSIDOauth2Factory;
@class WKWebView;

@interface MSALRequestParameters : NSObject <MSALRequestContext>

@property (nonatomic) NSURL *unvalidatedAuthority;
@property BOOL validateAuthority;
@property NSURL *cloudAuthority;
@property BOOL extendedLifetimeEnabled;
@property MSALScopes *scopes;
@property NSString *redirectUri;
@property NSString *loginHint;
@property NSString *clientId;
@property NSDictionary<NSString *, NSString *> *extraQueryParameters;
@property NSString *prompt;
@property MSALAccount *account;
@property MSALTelemetryApiId apiId;
@property NSDictionary<NSString *, NSString *> *sliceParameters;

@property MSALWebviewType webviewType;

@property WKWebView *customWebview;

#pragma mark MSALRequestContext properties
@property NSUUID *correlationId;
@property NSString *logComponent;
@property NSString *telemetryRequestId;
@property NSURLSession *urlSession;

@property (readonly) MSIDConfiguration *msidConfiguration;
@property MSIDOauth2Factory *msidOAuthFactory;

#pragma mark Methods
- (void)setScopesFromArray:(NSArray<NSString *> *)array;
- (BOOL)setAuthorityFromString:(NSString *)authority
                         error:(NSError * __autoreleasing *)error;
- (void)setCloudAuthorityWithCloudHostName:(NSString *)cloudHostName;
@end
