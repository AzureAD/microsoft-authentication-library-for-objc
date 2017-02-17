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
#import "MSALLogger.h"

@protocol MSALRequestContext

- (NSUUID *)correlationId;
- (NSString *)component;
- (NSString *)telemetryRequestId;
- (NSURLSession *)urlSession;

@end

@interface MSALLogger (Internal)

+ (NSDictionary *)msalId;
- (void)logLevel:(MSALLogLevel)level isPII:(BOOL)isPii context:(id<MSALRequestContext>)context format:(NSString *)format, ... NS_FORMAT_FUNCTION(4, 5);

@end

// Convenience macro for obscuring PII in log macros that don't allow PII.
#define _PII(_OBJ) _OBJ ? @"(not-nil)" : @"(nil)"

#define _LOG(_LVL, _PII, _CTX, _FMT, ...) [[MSALLogger sharedLogger] logLevel:_LVL isPII:_PII context:_CTX format:_FMT, ##__VA_ARGS__]

#define LOG_ERROR(ctx, fmt, ...)            _LOG(MSALLogLevelError, NO, ctx, fmt, ##__VA_ARGS__)
#define LOG_ERROR_PII(ctx, fmt, ...)        _LOG(MSALLogLevelError, YES, ctx, fmt, ##__VA_ARGS__)
#define LOG_WARN(ctx, fmt, ...)             _LOG(MSALLogLevelWarning, NO, ctx, fmt, ##__VA_ARGS__)
#define LOG_WARN_PII(ctx, fmt, ...)         _LOG(MSALLogLevelWarning, YES, ctx, fmt, ##__VA_ARGS__)
#define LOG_INFO(ctx, fmt, ...)             _LOG(MSALLogLevelInfo, NO, ctx, fmt, ##__VA_ARGS__)
#define LOG_INFO_PII(ctx, fmt, ...)         _LOG(MSALLogLevelInfo, YES, ctx, fmt, ##__VA_ARGS__)
#define LOG_VERBOSE(ctx, fmt, ...)          _LOG(MSALLogLevelVerbose, NO, ctx, fmt, ##__VA_ARGS__)
#define LOG_VERBSOE_PII(ctx, fmt, ...)      _LOG(MSALLogLevelVerbose, YES, ctx, fmt, ##__VA_ARGS__)
