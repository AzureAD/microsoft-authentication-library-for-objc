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

#import "MSALTestAppBoundSPAHarness.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDBrowserNativeMessageGetTokenRequest.h"
#import "MSALDefinitions.h"

NSErrorDomain const MSALTestAppBoundSPAHarnessErrorDomain =
    @"MSALTestAppBoundSPAHarnessErrorDomain";

typedef NS_ENUM(NSInteger, MSALTestAppBoundSPAHarnessErrorCode)
{
    MSALTestAppBoundSPAHarnessErrorInvalidJSON = 1,
    MSALTestAppBoundSPAHarnessErrorInvalidOrigin,
    MSALTestAppBoundSPAHarnessErrorContradictorySender,
    MSALTestAppBoundSPAHarnessErrorInvalidMode,
    MSALTestAppBoundSPAHarnessErrorProtocolOverride,
    MSALTestAppBoundSPAHarnessErrorRequestInFlight,
    MSALTestAppBoundSPAHarnessErrorInvalidResponse
};

@interface MSALTestAppBoundSPAHarness ()

@property (nonatomic, readwrite, getter=isRequestInFlight) BOOL requestInFlight;
@property (nonatomic, readwrite, copy, nullable) NSDictionary *originalRequestDictionary;
@property (nonatomic, readwrite, copy, nullable) NSDictionary *effectiveRequestDictionary;
@property (nonatomic, copy) MSALTestAppBoundSPAInvoker invoker;
@property (nonatomic) NSUInteger contextVersion;
@property (nonatomic, nullable) NSUUID *activeRunIdentifier;

@end

@implementation MSALTestAppBoundSPAHarness

- (instancetype)init
{
    return [self initWithInvoker:^(
        MSIDBrowserNativeMessageGetTokenRequest *request,
        void (^completionBlock)(NSString *response, NSError *error))
    {
        [MSALPublicClientApplication
            acquireBoundSPATokenWithRequest:request
                           completionBlock:completionBlock];
    }];
}

- (instancetype)initWithInvoker:(MSALTestAppBoundSPAInvoker)invoker
{
    NSParameterAssert(invoker);
    self = [super init];

    if (self)
    {
        _invoker = [invoker copy];
    }

    return self;
}

- (BOOL)submitJSONString:(NSString *)jsonString
              testOrigin:(NSString *)testOrigin
                    mode:(MSALTestAppBoundSPAMode)mode
        effectiveRequest:(NSDictionary **)effectiveRequest
              completion:(MSALTestAppBoundSPACompletion)completion
                   error:(NSError **)error
{
    NSParameterAssert(completion);

    @synchronized (self)
    {
        if (self.requestInFlight)
        {
            [self fillError:error
                       code:MSALTestAppBoundSPAHarnessErrorRequestInFlight
                description:@"A Bound SPA request is already in flight."
                 underlying:nil];
            return NO;
        }
    }

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id jsonObject = jsonData
        ? [NSJSONSerialization JSONObjectWithData:jsonData
                                         options:0
                                           error:&jsonError]
        : nil;
    if (![jsonObject isKindOfClass:NSDictionary.class])
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorInvalidJSON
            description:@"GetToken input must be a JSON object."
             underlying:jsonError];
        return NO;
    }

    NSDictionary *originalDictionary = [(NSDictionary *)jsonObject copy];
    NSDictionary *requestDictionary = originalDictionary[@"request"];
    if (![requestDictionary isKindOfClass:NSDictionary.class])
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorInvalidJSON
            description:@"GetToken input must contain a request object."
             underlying:nil];
        return NO;
    }

    NSURLComponents *origin = [self validatedOriginComponents:testOrigin
                                                        error:error];
    if (!origin)
    {
        return NO;
    }

    NSString *pastedSender = originalDictionary[@"sender"];
    if (pastedSender
        && (![pastedSender isKindOfClass:NSString.class]
            || ![self originString:pastedSender matchesOrigin:origin]))
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorContradictorySender
            description:@"The pasted sender contradicts the configured test origin."
             underlying:nil];
        return NO;
    }

    if (![self validateNoProtocolOverridesInDictionary:originalDictionary
                                                 error:error]
        || ![self validateNoProtocolOverridesInDictionary:requestDictionary
                                                     error:error])
    {
        return NO;
    }

    NSMutableDictionary *effectiveDictionary = [originalDictionary mutableCopy];
    NSMutableDictionary *effectiveInnerRequest = [requestDictionary mutableCopy];
    effectiveDictionary[@"sender"] = origin.URL.absoluteString;

    NSUUID *correlationId = NSUUID.UUID;
    effectiveInnerRequest[@"correlationId"] = correlationId.UUIDString;
    effectiveInnerRequest[@"state"] = NSUUID.UUID.UUIDString;
    effectiveInnerRequest[@"nonce"] = NSUUID.UUID.UUIDString;

    if (![self applyMode:mode toRequest:effectiveInnerRequest error:error])
    {
        return NO;
    }

    effectiveDictionary[@"request"] = effectiveInnerRequest;

    NSError *requestError = nil;
    MSIDBrowserNativeMessageGetTokenRequest *request =
        [[MSIDBrowserNativeMessageGetTokenRequest alloc]
            initWithJSONDictionary:effectiveDictionary
                             error:&requestError];
    if (!request)
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorInvalidJSON
            description:@"The native GetToken parser rejected the request."
             underlying:requestError];
        return NO;
    }

    NSUUID *runIdentifier = NSUUID.UUID;
    NSUInteger runContextVersion = 0;
    @synchronized (self)
    {
        if (self.requestInFlight)
        {
            [self fillError:error
                       code:MSALTestAppBoundSPAHarnessErrorRequestInFlight
                description:@"A Bound SPA request is already in flight."
                 underlying:nil];
            return NO;
        }

        self.originalRequestDictionary = originalDictionary;
        self.effectiveRequestDictionary = [effectiveDictionary copy];
        self.requestInFlight = YES;
        self.activeRunIdentifier = runIdentifier;
        runContextVersion = self.contextVersion;
    }

    if (effectiveRequest)
    {
        *effectiveRequest = self.effectiveRequestDictionary;
    }

    __weak typeof(self) weakSelf = self;
    self.invoker(request, ^(NSString *response, NSError *nativeError)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
        {
            return;
        }

        BOOL stale = NO;
        @synchronized (strongSelf)
        {
            if (![strongSelf.activeRunIdentifier isEqual:runIdentifier])
            {
                return;
            }

            stale = strongSelf.contextVersion != runContextVersion;
            strongSelf.activeRunIdentifier = nil;
            strongSelf.requestInFlight = NO;
        }

        NSError *presentationError = nativeError;
        NSString *presentation = nil;
        if (nativeError)
        {
            presentation = [strongSelf presentationForError:nativeError mode:mode];
        }
        else
        {
            presentation = [strongSelf presentationForResponse:response
                                                 expectedState:request.state
                                                          mode:mode
                                                         error:&presentationError];
        }

        completion(presentation ?: @"Bound SPA request completed without a result.",
                   presentationError,
                   stale);
    });

    return YES;
}

- (void)invalidateContext
{
    @synchronized (self)
    {
        self.contextVersion++;
    }
}

+ (NSString *)displayNameForMode:(MSALTestAppBoundSPAMode)mode
{
    switch (mode)
    {
        case MSALTestAppBoundSPAModeInteractive:
            return @"Interactive (select_account, UI allowed)";

        case MSALTestAppBoundSPAModeSilentOnly:
            return @"Silent only (prompt=none, UI blocked)";

        case MSALTestAppBoundSPAModeSilentWithInteractiveRecovery:
            return @"Silent with interactive recovery (prompt omitted, UI allowed)";
    }

    return @"Unknown";
}

#pragma mark - Request validation

- (nullable NSURLComponents *)validatedOriginComponents:(NSString *)originString
                                                   error:(NSError **)error
{
    NSURLComponents *origin = [NSURLComponents
        componentsWithString:originString ?: @""];
    BOOL valid = [origin.scheme.lowercaseString isEqualToString:@"https"]
        && origin.host.length
        && !origin.user
        && !origin.password
        && !origin.query
        && !origin.fragment
        && (!origin.path.length || [origin.path isEqualToString:@"/"]);
    if (!valid)
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorInvalidOrigin
            description:@"Test origin must be an HTTPS origin without a path, query, or fragment."
             underlying:nil];
        return nil;
    }

    origin.scheme = origin.scheme.lowercaseString;
    origin.host = origin.host.lowercaseString;
    origin.path = @"";
    return origin;
}

- (BOOL)originString:(NSString *)originString
       matchesOrigin:(NSURLComponents *)expectedOrigin
{
    NSURLComponents *origin = [NSURLComponents componentsWithString:originString];
    BOOL validOrigin = [origin.scheme.lowercaseString isEqualToString:@"https"]
        && origin.host.length
        && !origin.user
        && !origin.password
        && !origin.query
        && !origin.fragment
        && (!origin.path.length || [origin.path isEqualToString:@"/"]);
    if (!validOrigin)
    {
        return NO;
    }

    NSNumber *originPort = origin.port ?: @443;
    NSNumber *expectedPort = expectedOrigin.port ?: @443;
    return [origin.host.lowercaseString
               isEqualToString:expectedOrigin.host.lowercaseString]
        && [originPort isEqual:expectedPort];
}

- (BOOL)validateNoProtocolOverridesInDictionary:(NSDictionary *)dictionary
                                          error:(NSError **)error
{
    NSDictionary *extraParameters = dictionary[@"extraParameters"];
    if (extraParameters
        && ![extraParameters isKindOfClass:NSDictionary.class])
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorProtocolOverride
            description:@"extraParameters must be a JSON object."
             underlying:nil];
        return NO;
    }

    for (NSDictionary *candidateDictionary in
         @[dictionary, extraParameters ?: @{}])
    {
        for (id rawKey in candidateDictionary)
        {
            if ([self isReservedProtocolKey:rawKey])
            {
                [self fillError:error
                           code:MSALTestAppBoundSPAHarnessErrorProtocolOverride
                    description:@"Native Broker transport and protocol fields are not accepted by this harness."
                     underlying:nil];
                return NO;
            }
        }
    }

    return YES;
}

- (BOOL)isReservedProtocolKey:(id)rawKey
{
    NSString *key = [rawKey isKindOfClass:NSString.class]
        ? [rawKey lowercaseString]
        : nil;
    return !key
        || [key hasPrefix:@"bound_"]
        || [key hasPrefix:@"brk_"]
        || [key hasPrefix:@"broker_"]
        || [@[@"child_client_id",
              @"child_redirect_uri",
              @"sdk_broker_capabilities",
              @"msg_protocol_ver",
              @"request_nonce",
              @"refresh_token",
              @"grant_type"] containsObject:key];
}

- (BOOL)applyMode:(MSALTestAppBoundSPAMode)mode
        toRequest:(NSMutableDictionary *)request
            error:(NSError **)error
{
    switch (mode)
    {
        case MSALTestAppBoundSPAModeInteractive:
            request[@"prompt"] = @"select_account";
            request[@"canShowUI"] = @YES;
            return YES;

        case MSALTestAppBoundSPAModeSilentOnly:
            request[@"prompt"] = @"none";
            request[@"canShowUI"] = @NO;
            break;

        case MSALTestAppBoundSPAModeSilentWithInteractiveRecovery:
            [request removeObjectForKey:@"prompt"];
            request[@"canShowUI"] = @YES;
            break;

        default:
            [self fillError:error
                       code:MSALTestAppBoundSPAHarnessErrorInvalidMode
                description:@"Unknown Bound SPA test mode."
                 underlying:nil];
            return NO;
    }

    NSString *accountId = request[@"accountId"];
    NSString *loginHint = request[@"loginHint"];
    BOOL hasAccountId = [accountId isKindOfClass:NSString.class]
        && accountId.length;
    BOOL hasLoginHint = [loginHint isKindOfClass:NSString.class]
        && loginHint.length;
    if (!hasAccountId && !hasLoginHint)
    {
        [self fillError:error
                   code:MSALTestAppBoundSPAHarnessErrorInvalidMode
            description:@"Silent and recovery modes require request.accountId or request.loginHint."
             underlying:nil];
        return NO;
    }

    return YES;
}

#pragma mark - Presentation

- (NSString *)presentationForResponse:(NSString *)response
                        expectedState:(NSString *)expectedState
                                 mode:(MSALTestAppBoundSPAMode)mode
                                error:(NSError **)error
{
    NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id responseObject = responseData
        ? [NSJSONSerialization JSONObjectWithData:responseData
                                         options:0
                                           error:&jsonError]
        : nil;
    if (![responseObject isKindOfClass:NSDictionary.class])
    {
        NSError *responseError = nil;
        [self fillError:&responseError
                   code:MSALTestAppBoundSPAHarnessErrorInvalidResponse
            description:@"The Bound SPA response is not a JSON object."
             underlying:jsonError];
        if (error) *error = responseError;
        return [self presentationForError:responseError mode:mode];
    }

    NSDictionary *responseDictionary = responseObject;
    for (id responseKey in responseDictionary)
    {
        if ([self isReservedProtocolKey:responseKey])
        {
            NSError *responseError = nil;
            [self fillError:&responseError
                       code:MSALTestAppBoundSPAHarnessErrorInvalidResponse
                description:@"The response contains a native or refresh-token field that must not be exposed."
                 underlying:nil];
            if (error) *error = responseError;
            return [self presentationForError:responseError mode:mode];
        }
    }

    NSString *accessToken = responseDictionary[@"access_token"];
    NSDictionary *account = responseDictionary[@"account"];
    NSString *accountId = [account isKindOfClass:NSDictionary.class]
        ? account[@"id"]
        : nil;
    NSString *state = responseDictionary[@"state"];
    BOOL valid = [accessToken isKindOfClass:NSString.class]
        && accessToken.length
        && [accountId isKindOfClass:NSString.class]
        && accountId.length
        && [state isKindOfClass:NSString.class]
        && [state isEqualToString:expectedState];
    if (!valid)
    {
        NSError *responseError = nil;
        [self fillError:&responseError
                   code:MSALTestAppBoundSPAHarnessErrorInvalidResponse
            description:@"The response is missing access_token, account.id, or the preserved OAuth state."
             underlying:nil];
        if (error) *error = responseError;
        return [self presentationForError:responseError mode:mode];
    }

    NSString *idToken = responseDictionary[@"id_token"];
    NSString *scope = responseDictionary[@"scope"];
    id expiresIn = responseDictionary[@"expires_in"];
    NSString *userName = account[@"userName"];

    return [NSString stringWithFormat:
        @"Bound SPA GetToken succeeded\n"
         "mode: %@\n"
         "validation: required fields present; state preserved\n"
         "account.id: %@\n"
         "account.userName: %@\n"
         "access_token: present (redacted)\n"
         "id_token: %@\n"
         "refresh_token: absent\n"
         "scope: %@\n"
         "expires_in: %@",
        [self.class displayNameForMode:mode],
        accountId,
        [userName isKindOfClass:NSString.class] && userName.length
            ? @"present (redacted)"
            : @"absent",
        [idToken isKindOfClass:NSString.class] && idToken.length
            ? @"present (redacted)"
            : @"absent",
        [scope isKindOfClass:NSString.class] ? scope : @"absent",
        expiresIn ?: @"absent"];
}

- (NSString *)presentationForError:(NSError *)error
                              mode:(MSALTestAppBoundSPAMode)mode
{
    NSString *browserStatus =
        error.userInfo[@"MSALBrowserNativeMessageErrorStatus"];
    NSString *correlationId = error.userInfo[MSALCorrelationIDKey];
    NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    NSMutableString *presentation = [NSMutableString stringWithFormat:
        @"Bound SPA GetToken failed\n"
         "mode: %@\n"
         "domain: %@\n"
         "code: %ld\n"
         "browser status: %@\n"
         "correlation ID: %@\n"
         "description: %@",
        [self.class displayNameForMode:mode],
        error.domain,
        (long)error.code,
        browserStatus ?: @"absent",
        correlationId ?: @"absent",
        error.localizedDescription];
    if (underlyingError)
    {
        [presentation appendFormat:@"\nunderlying domain/code: %@/%ld",
                                   underlyingError.domain,
                                   (long)underlyingError.code];
    }

    return presentation;
}

#pragma mark - Error

- (void)fillError:(NSError **)error
             code:(MSALTestAppBoundSPAHarnessErrorCode)code
      description:(NSString *)description
       underlying:(nullable NSError *)underlying
{
    if (!error)
    {
        return;
    }

    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey : description
    } mutableCopy];
    if (underlying)
    {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    *error = [NSError errorWithDomain:MSALTestAppBoundSPAHarnessErrorDomain
                                 code:code
                             userInfo:userInfo];
}

@end
