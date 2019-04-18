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
#import "MSALDefinitions.h"

@interface MSALLogger : NSObject

- (nonnull instancetype)init NS_UNAVAILABLE;

+ (nonnull MSALLogger *)sharedLogger DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.loggerConfig instead");
                                                            

/*!
    The minimum log level for messages to be passed onto the log callback.
 */
@property (readwrite) MSALLogLevel level DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.loggerConfig.logLevel instead");

/*!
    MSAL provides logging callbacks that assist in diagnostics. There is a boolean value in the logging callback that indicates whether the message contains user information. If PiiLoggingEnabled is set to NO, the callback will not be triggered for log messages that contain any user information. By default the library will not return any messages with user information in them.
 */
@property (readwrite) BOOL PiiLoggingEnabled DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.loggerConfig.piiEnabled instead");

/*!
    Sets the callback block to send MSAL log messages to.
 
    NOTE: Once this is set this can not be unset, and it should be set early in
          the program's execution.
 */
- (void)setCallback:(nonnull MSALLogCallback)callback DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.loggerConfig setLogCallback: instead");;

@end
