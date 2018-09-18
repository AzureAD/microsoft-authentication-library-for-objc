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

#import "MSIDTestURLResponse.h"

@class MSALAccount;

@interface MSIDTestURLResponse (MSAL)

+ (MSIDTestURLResponse *)discoveryResponseForAuthority:(NSString *)authority;

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority;

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
                                      responseUrl:(NSString *)responseAuthority
                                            query:(NSString *)query;

+ (MSIDTestURLResponse *)rtResponseForScopes:(MSALScopes *)scopes
                                   authority:(NSString *)authority
                                    tenantId:(NSString *)tid
                                        user:(MSALAccount *)user;

+ (MSIDTestURLResponse *)errorRtResponseForScopes:(MSALScopes *)scopes
                                        authority:(NSString *)authority
                                         tenantId:(NSString *)tid
                                          account:(MSALAccount *)account
                                        errorCode:(NSString *)errorCode
                                 errorDescription:(NSString *)errorDescription
                                         subError:(NSString *)subError;

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(MSALScopes *)scopes;

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(MSALScopes *)scopes
                               clientInfo:(NSDictionary *)clientInfo;

+ (MSIDTestURLResponse *)serverNotFoundResponseForURLString:(NSString *)requestUrlString
                                             requestHeaders:(NSDictionary *)requestHeaders
                                          requestParamsBody:(id)requestParams;

+ (NSDictionary *)defaultQueryParameters;

@end
