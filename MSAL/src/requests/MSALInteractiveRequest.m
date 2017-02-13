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

#import "MSALInteractiveRequest.h"
#import "MSALOAuth2Constants.h"
#import "MSALUIBehavior_Internal.h"

@implementation MSALInteractiveRequest

- (id)initWithParameters:(MSALRequestParameters *)parameters
        additionalScopes:(NSArray<NSString *> *)additionalScopes
                behavior:(MSALUIBehavior)behavior
                   error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithParameters:parameters
                                     error:error]))
    {
        return nil;
    }
    
    if (additionalScopes)
    {
        _additionalScopes = [[NSOrderedSet alloc] initWithArray:additionalScopes];
        if (![self validateScopeInput:_additionalScopes error:error])
        {
            return nil;
        }
    }
    
    _uiBehavior = behavior;
    
    return self;
}

- (NSMutableDictionary<NSString *, NSString *> *)authorizationParameters
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary new];
    if (_parameters.extraQueryParameters)
    {
        [parameters addEntriesFromDictionary:_parameters.extraQueryParameters];
    }
    MSALScopes *allScopes = [self requestScopes:_additionalScopes];
    parameters[OAUTH2_SCOPE] = [allScopes msalToString];
    parameters[OAUTH2_RESPONSE_TYPE] = OAUTH2_CODE;
    parameters[OAUTH2_REDIRECT_URI] = [_parameters.redirectUri absoluteString];
    parameters[OAUTH2_CORRELATION_ID_REQUEST] = [_parameters.correlationId UUIDString];
    
    NSDictionary* msalId = [MSALLogger msalId];
    [parameters addEntriesFromDictionary:msalId];
    [parameters addEntriesFromDictionary:MSALParametersForBehavior(_uiBehavior)];
    
    return parameters;
}

- (NSURL *)authorizationUrl
{
    NSDictionary <NSString *, NSString *> *parameters = [self authorizationParameters];
    // TODO: PKCE Support
    
    _state = [[NSUUID UUID] UUIDString];
    
    
    (void)parameters;
    return nil;
}

- (void)acquireToken:(MSALCompletionBlock)completionBlock
{
    NSURL *authorizationUrl = [self authorizationUrl];
    (void)authorizationUrl;
    (void)completionBlock;
}

@end
