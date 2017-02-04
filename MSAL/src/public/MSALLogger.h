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

/*! Levels of logging. Defines the priority of the logged message */
typedef NS_ENUM(NSInteger, MSALLogLevel)
{
    MSALLogLevelNothing,
    MSALLogLevelError,
    MSALLogLevelWarning,
    MSALLogLevelInfo,
    MSALLogLevelVerbose,
    MSALLogLevelLast = MSALLogLevelVerbose,
};


/*!
    The LogCallback block for the MSAL logger
 
    @param  logLevel        The level of the log message
    @param  message         A short log message describing the event that occurred, this string will not contain PII.
    @param  additionalInfo  A longer message that may contain PII and other details relevant to the event.
    @param  userInfo        A dictionary with other information relevant to the log message. The information varies,
                            for most error messages the error object will be in the "error" key.
 */
typedef void (^MSALLogCallback)(MSALLogLevel logLevel, NSString *message, NSString *additionalInfo, NSDictionary *userInfo);


@interface MSALLogger : NSObject

+ (MSALLogger *)sharedLogger;

/*!
    The minimum log level for messages to be passed onto the log callback.
 */
@property (readwrite) MSALLogLevel level;

/*!
    Sets the callback block to send MSAL log messages to.
 
    NOTE: Once this is set this can not be unset, and it should be set early in
          the program's execution.
 */
- (void)setCallback:(MSALLogCallback)callback;

@end
