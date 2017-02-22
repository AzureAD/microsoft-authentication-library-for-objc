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


#import "MSALPublicClientApplication.h"

#import "MSALAuthority.h"
#import "MSALError.h"
#import "MSALError_Internal.h"
#import "MSALInteractiveRequest.h"
#import "MSALRequestParameters.h"
#import "MSALUIBehavior_Internal.h"
#import "MSALWebUI.h"

#define DEFAULT_AUTHORITY @"https://login.microsoftonline.com/common"

@implementation MSALPublicClientApplication

- (BOOL)generateRedirectUri:(NSError * __autoreleasing *)error
{
    (void)error; // TODO
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString *scheme = [NSString stringWithFormat:@"x-msauth-%@", [bundleId stringByReplacingOccurrencesOfString:@"." withString:@"-"]];
    
    NSArray* urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    
    for (NSDictionary* urlRole in urlTypes)
    {
        NSArray* urlSchemes = [urlRole objectForKey:@"CFBundleURLSchemes"];
        if ([urlSchemes containsObject:scheme])
        {
            NSString *redirectUri = [NSString stringWithFormat:@"%@://%@/msal", scheme, bundleId];
            _redirectUri = [NSURL URLWithString:redirectUri];
            return YES;
        }
    }
    
    MSAL_ERROR_PARAM(nil, MSALErrorRedirectSchemeNotRegistered, @"The required app scheme is not registered in the app's info.plist file.");
    
    return NO;
}

- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId authority:nil error:error];
}
- (id)initWithClientId:(NSString *)clientId
             authority:(NSString *)authority
                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    REQUIRED_PARAMETER(clientId, nil);
    _clientId = clientId;
    
    _authority = [MSALAuthority checkAuthorityString:authority ? authority : DEFAULT_AUTHORITY error:error];
    CHECK_RETURN_NIL(_authority);
    
    CHECK_RETURN_NIL([self generateRedirectUri:error]);
    
    return self;
}

- (NSArray <MSALUser *> *)users
{
    return nil;
}

#pragma SafariViewController Support

+ (BOOL)isMSALResponse:(NSURL *)response
{
    if (!response)
    {
        return NO;
    }
    
    MSALInteractiveRequest *request = [MSALInteractiveRequest currentActiveRequest];
    if (!request)
    {
        return NO;
    }
    
    if ([NSString msalIsStringNilOrBlank:response.query])
    {
        return NO;
    }
    
    NSDictionary *qps = [NSDictionary msalURLFormDecode:response.query];
    if (!qps)
    {
        return NO;
    }
    
    NSString *state = qps[OAUTH2_STATE];
    if (!state)
    {
        return NO;
    }
    
    if (![request.state isEqualToString:state])
    {
        LOG_ERROR(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
        LOG_ERROR_PII(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
        return NO;
    }
    
    return YES;
}

+ (void)handleMSALResponse:(NSURL *)response
{
    [MSALWebUI handleResponse:response];
}

+ (void)cancelCurrentWebAuthSession
{
    [MSALWebUI cancelCurrentWebAuthSession];
}

#pragma mark -
#pragma mark acquireToken

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
               additionalScopes:nil
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
               additionalScopes:nil
                      loginHint:loginHint
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
               additionalScopes:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:nil
                  correlationId:nil
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
             additionalScopes:(NSArray<NSString *> *)additionalScopes
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSString *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALRequestParameters* params = [MSALRequestParameters new];
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.component = _component;
    LOG_INFO(params, @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                      "                                   additionalScopes:%@\n"
                      "                                          loginHint:%@\n"
                      "                                         uiBehavior:%@\n"
                      "                               extraQueryParameters:%@\n"
                      "                                          authority:%@\n"
                      "                                      correlationId:%@]",
             scopes, additionalScopes, _PII(loginHint), MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, _PII(authority), correlationId);
    LOG_INFO_PII(params, @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                          "                                   additionalScopes:%@\n"
                          "                                          loginHint:%@\n"
                          "                                         uiBehavior:%@\n"
                          "                               extraQueryParameters:%@\n"
                          "                                          authority:%@\n"
                          "                                      correlationId:%@]",
             scopes, additionalScopes, loginHint, MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, authority, correlationId);
    
    [params setScopesFromArray:scopes];
    params.loginHint = loginHint;
    params.extraQueryParameters = extraQueryParameters;
    if (authority)
    {
        NSError *error = nil;
        NSURL *authorityUrl = [MSALAuthority checkAuthorityString:authority error:&error];
        if (!authorityUrl)
        {
            completionBlock(nil, error);
            return;
        }
        params.unvalidatedAuthority = authorityUrl;
    }
    else
    {
        params.unvalidatedAuthority = _authority;
    }
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    
    NSError *error = nil;
    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:params
                                      additionalScopes:additionalScopes
                                              behavior:uiBehavior
                                                 error:&error];
    if (!request)
    {
        completionBlock(nil, error);
        return;
    }
    
    [request run:completionBlock];
}

#pragma mark -
#pragma mark User

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                         user:(MSALUser *)user
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    // TODO
    (void)scopes;
    (void)user;
    (void)uiBehavior;
    (void)extraQueryParameters;
    (void)completionBlock;
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
             additionalScopes:(NSArray<NSString *> *)additionalScopes
                         user:(MSALUser *)user
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSURL *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    // TODO
    (void)scopes;
    (void)additionalScopes;
    (void)user;
    (void)uiBehavior;
    (void)extraQueryParameters;
    (void)authority;
    (void)correlationId;
    (void)completionBlock;
}

#pragma mark Silent

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                               user:(MSALUser *)user
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    // TODO
    (void)scopes;
    (void)user;
    (void)completionBlock;
}

@end
