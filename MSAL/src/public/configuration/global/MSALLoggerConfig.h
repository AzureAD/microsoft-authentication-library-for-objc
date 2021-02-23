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

/*! Levels of log masking */
typedef NS_ENUM(NSInteger, MSALLogMaskingLevel)
{
    /** MSAL will not return any messages with any user or organizational information. This includes EUII and EUPI. This is the default level. */
    MSALLogMaskingSettingsMaskAllPII,
    
    /** MSAL logs will still include OII (organization identifiable information), and EUPI (end user pseudonymous identifiers), but MSAL will try to exclude and/or mask any EUII (end user identifiable information) like UPN, username, email from its logs. */
    
    MSALLogMaskingSettingsMaskEUIIOnly,
    
    /** MSAL logs will still include OII (organization identifiable information),  EUPI (end user pseudonymous identifiers), and EUII (end user identifiable information) like UPN, username, email from its logs. MSAL will still hide all secrets like tokens from its logs */
    MSALLogMaskingSettingsMaskSecretsOnly
};

NS_ASSUME_NONNULL_BEGIN

/**
    MSAL configuration interface responsible for setting up MSAL logging callback and configuring log collection behavior.
    @note Configuration changes inside MSALLoggerConfig will apply to all instances of `MSALPublicClientApplication`
*/
@interface MSALLoggerConfig : NSObject

#pragma mark - Configuring log collection

/**
 The minimum log level for messages to be passed onto the log callback.
 */
@property (atomic) MSALLogLevel logLevel;
/**
 MSAL provides logging callbacks that assist in diagnostics. There is a boolean value in the logging callback that indicates whether the message contains user information. If piiEnabled is set to NO, the callback will not be triggered for log messages that contain any user information. By default the library will not return any messages with user information in them.
 */
@property (nonatomic) BOOL piiEnabled DEPRECATED_MSG_ATTRIBUTE("Use logMaskingLevel instead");

/**
 MSAL provides logging callbacks that assist in diagnostics. By default the library will not return any messages with any user or organizational information. However, this might make diagnosing issues difficult.
 logMaskingLevel property can be used to adjust level of MSAL masking.
 Default value is MSALLogMaskingSettingsMaskAllPII.
*/
@property (nonatomic) MSALLogMaskingLevel logMaskingLevel;

#pragma mark - Setting up the logging callback

/**
 Sets the callback block to send MSAL log messages to.
 
 @note Once this is set this can not be unset, and it should be set early in the program's execution.
 
 @note MSAL logs might contain potentially sensitive information. When implementing MSAL logging, you should never output MSAL logs with NSLog or print directly, unless you're running your application in the debug mode. If you're writing MSAL logs to file, you must take necessary precautions to store the file securely.
 
 Additionally, MSAL makes determination regarding PII status of a particular parameter based on the parameter type. It wouldn't automatically detect a case where PII information is passed into non-PII parameter due to a developer mistake (e.g. MSAL doesn't consider clientId PII and it expects developers to exersice caution and never pass any unexpected sensitive information into that parameter).
 */
- (void)setLogCallback:(MSALLogCallback)callback;

/**
    Read current MSAL logging callback.
 */
- (MSALLogCallback)callback;


#pragma mark - Unavailable initializers

/**
   Use class properties instead.
*/
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   Use class properties instead.
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
