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

#import "MSALLoggerConfig+Internal.h"
#import "MSIDLogger.h"

@implementation MSALLoggerConfig

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static MSALLoggerConfig *s_loggerConfig;
    
    dispatch_once(&once, ^{
        s_loggerConfig = [[self.class alloc] init];
        
        [[MSIDLogger sharedLogger] setCallback:^(MSIDLogLevel level, NSString *message, BOOL containsPII) {
            
            if (s_loggerConfig->_callback)
            {
                s_loggerConfig->_callback((MSALLogLevel)level, message, containsPII);
            }
            
        }];
    });
    return s_loggerConfig;
}

- (void)setLogCallback:(MSALLogCallback)callback
{
    if (self.callback != nil)
    {
        @throw @"MSAL logging callback can only be set once per process and should never changed once set.";
    }
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        self.callback = callback;
    });
}

#pragma mark - Level

- (void)setLogLevel:(MSALLogLevel)level
{
    [MSIDLogger sharedLogger].level = (MSIDLogLevel)level;
}

- (MSALLogLevel)logLevel
{
    return (MSALLogLevel)[MSIDLogger sharedLogger].level;
}

#pragma mark - Pii logging

- (void)setPiiEnabled:(BOOL)piiEnabled
{
    [MSIDLogger sharedLogger].PiiLoggingEnabled = piiEnabled;
}

- (BOOL)piiEnabled
{
    return [MSIDLogger sharedLogger].PiiLoggingEnabled;
}

@end
