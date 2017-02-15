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

/*!
    This class provides a logging callback for the MSAL logger and allows tests
    to inspect the last log message sent to the logger. It is automatically reset
    at the beginning of each test by MSALTestCase.
 */
@interface MSALTestLogger : NSObject

@property (readwrite) BOOL containsPII;
@property (readwrite, retain) NSString *lastMessage;
@property (readwrite) MSALLogLevel lastLevel;

+ (MSALTestLogger *)sharedLogger;

/*! Resets all of the test logger variables to default state and sets the MSAL log level to MSALLogLevelLast. */
- (void)reset;

/*! Resets all of the test logger variables to default state and sets the MSAL log level to the provided log level. */
- (void)reset:(MSALLogLevel)level;

@end
