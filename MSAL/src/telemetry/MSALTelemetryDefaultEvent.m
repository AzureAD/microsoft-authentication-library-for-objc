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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALTelemetryDefaultEvent.h"
#import "MSALTelemetryEventStrings.h"
#import "MSALIpAddressHelper.h"
#import "MSALLogger+Internal.h"
#include <CoreFoundation/CoreFoundation.h>

#if !TARGET_OS_IPHONE
#include <IOKit/IOKitLib.h>
#endif

@implementation MSALTelemetryDefaultEvent

- (id)initWithName:(NSString *)eventName
         context:(id<MSALRequestContext>)context
{
    if (!(self = [super initWithName:eventName context:context]))
    {
        return nil;
    }
    
    [self addDefaultParameters];
    
    return self;
}

- (void)addDefaultParameters
{
    static dispatch_once_t s_parametersOnce;
    
    dispatch_once(&s_parametersOnce, ^{
        
#if TARGET_OS_IPHONE
        //iOS:
        NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        NSString *applicationName = [[NSBundle mainBundle] bundleIdentifier];
#else
        CFStringRef macSerialNumber = nil;
        CopySerialNumber(&macSerialNumber);
        NSString *deviceId = CFBridgingRelease(macSerialNumber);
        NSString *applicationName = [[NSProcessInfo processInfo] processName];
#endif
        
        [self setProperty:MSAL_TELEMETRY_KEY_DEVICE_ID value:[deviceId msalComputeSHA256Hex]];
        [self setProperty:MSAL_TELEMETRY_KEY_APPLICATION_NAME value:applicationName];
        [self setProperty:MSAL_TELEMETRY_KEY_APPLICATION_VERSION value:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
        
        NSDictionary *msalIds = [MSALLogger msalId];
        for (NSString *key in msalIds)
        {
            NSString *propertyName = [NSString stringWithFormat:@"msal.%@",
                                      [[key lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
            
            [self setProperty:propertyName value:[msalIds objectForKey:key]];
        }
    });
    
    [self setProperty:MSAL_TELEMETRY_KEY_DEVICE_IP_ADDRESS value:[MSALIpAddressHelper msalDeviceIpAddress]];
}

#if !TARGET_OS_IPHONE
// Returns the serial number as a CFString.
// It is the caller's responsibility to release the returned CFString when done with it.
void CopySerialNumber(CFStringRef *serialNumber)
{
    if (serialNumber != NULL) {
        *serialNumber = NULL;
        
        io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                                     IOServiceMatching("IOPlatformExpertDevice"));
        
        if (platformExpert) {
            CFTypeRef serialNumberAsCFString =
            IORegistryEntryCreateCFProperty(platformExpert,
                                            CFSTR(kIOPlatformSerialNumberKey),
                                            kCFAllocatorDefault, 0);
            if (serialNumberAsCFString) {
                *serialNumber = serialNumberAsCFString;
            }
            
            IOObjectRelease(platformExpert);
        }
    }
}
#endif

@end
