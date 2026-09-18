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

@class MSIDBrowserNativeMessageGetTokenRequest;

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const MSALTestAppBoundSPAHarnessErrorDomain;

typedef NS_ENUM(NSInteger, MSALTestAppBoundSPAMode)
{
    MSALTestAppBoundSPAModeInteractive,
    MSALTestAppBoundSPAModeSilentOnly,
    MSALTestAppBoundSPAModeSilentWithInteractiveRecovery
};

typedef void (^MSALTestAppBoundSPAInvoker)(
    MSIDBrowserNativeMessageGetTokenRequest *request,
    void (^completionBlock)(NSString * _Nullable response,
                            NSError * _Nullable error));

typedef void (^MSALTestAppBoundSPACompletion)(
    NSString *presentation,
    NSError * _Nullable error,
    BOOL stale);

@interface MSALTestAppBoundSPAHarness : NSObject

@property (nonatomic, readonly, getter=isRequestInFlight) BOOL requestInFlight;
@property (nonatomic, readonly, nullable) NSDictionary *originalRequestDictionary;
@property (nonatomic, readonly, nullable) NSDictionary *effectiveRequestDictionary;

- (instancetype)init;

- (instancetype)initWithInvoker:(MSALTestAppBoundSPAInvoker)invoker
    NS_DESIGNATED_INITIALIZER;

- (BOOL)submitJSONString:(NSString *)jsonString
              testOrigin:(NSString *)testOrigin
                    mode:(MSALTestAppBoundSPAMode)mode
        effectiveRequest:(NSDictionary * _Nullable * _Nullable)effectiveRequest
              completion:(MSALTestAppBoundSPACompletion)completion
                   error:(NSError * _Nullable * _Nullable)error;

- (void)invalidateContext;

+ (NSString *)displayNameForMode:(MSALTestAppBoundSPAMode)mode;

@end

NS_ASSUME_NONNULL_END
