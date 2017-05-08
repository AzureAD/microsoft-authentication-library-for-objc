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

#import "MSALLogger+Internal.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/machine.h>
#include <CommonCrypto/CommonDigest.h>

#define MSAL_ID_PLATFORM   @"x-client-SKU"
#define MSAL_ID_VERSION  @"x-client-Ver"
#define MSAL_ID_CPU  @"x-client-CPU"
#define MSAL_ID_OS_VER @"x-client-OS"
#define MSAL_ID_DEVICE_MODEL @"x-client-DM"


#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@implementation MSALLogger
{
    MSALLogCallback _callback;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // The default log level should be info, anything more restrictive then this
    // and we'll probably not have enough diagnostic information, however verbose
    // will most likely be too noisy for most usage.
    self.level = MSALLogLevelInfo;
    self.PiiLoggingEnabled = NO;
    
    return self;
}

+ (MSALLogger *)sharedLogger
{
    static dispatch_once_t once;
    static MSALLogger *s_logger;
    
    dispatch_once(&once, ^{
        s_logger = [MSALLogger new];
    });
    
    return s_logger;
}

- (void)setCallback:(MSALLogCallback)callback
{
    static dispatch_once_t once;
    
    if (self->_callback != nil)
    {
        @throw @"MSAL logging callback can only be set once per process and should never changed once set.";
    }
    
    dispatch_once(&once, ^{
        self->_callback = callback;
    });
}

@end

@implementation MSALLogger (Internal)

static NSString *s_OSString = nil;
static NSDateFormatter *s_dateFormatter = nil;

+ (void)initialize
{
#if TARGET_OS_IPHONE
    UIDevice* device = [UIDevice currentDevice];
    
#if TARGET_OS_SIMULATOR
    s_OSString = [NSString stringWithFormat:@"iOS Sim %@", device.systemVersion];
#else
    s_OSString = [NSString stringWithFormat:@"iOS %@", device.systemVersion];
#endif
#elif TARGET_OS_WATCH
#error watchOS is not supported
#elif TARGET_OS_TV
#error tvOS is not supported
#else
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    s_OSString = [NSString stringWithFormat:@"Mac %ld.%ld.%ld", (long)osVersion.majorVersion, (long)osVersion.minorVersion, (long)osVersion.patchVersion];
#endif
    
    s_dateFormatter = [[NSDateFormatter alloc] init];
    [s_dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    [s_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
}

//Extracts the CPU information according to the constants defined in
//machine.h file. The method prints minimal information - only if 32 or
//64 bit CPU architecture is being used.
+ (NSString*)getCPUInfo
{
    size_t structSize;
    cpu_type_t cpuType;
    structSize = sizeof(cpuType);
    
    //Extract the CPU type. E.g. x86. See machine.h for details
    //See sysctl.h for details.
    int result = sysctlbyname("hw.cputype", &cpuType, &structSize, NULL, 0);
    if (result)
    {
        LOG_WARN(nil, @"Cannot extract cpu type. Error: %d", result);
        return nil;
    }
    
    return (CPU_ARCH_ABI64 & cpuType) ? @"64" : @"32";
}


+ (NSDictionary *)msalId
{
    static NSDictionary* msalId;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
#if TARGET_OS_IPHONE
        //iOS:
        UIDevice* device = [UIDevice currentDevice];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:
                                       @{
                                         MSAL_ID_PLATFORM:@"MSAL.iOS",
                                         MSAL_ID_VERSION:@MSAL_VERSION_STRING,
                                         MSAL_ID_OS_VER:device.systemVersion,
                                         MSAL_ID_DEVICE_MODEL:device.model,//Prints out only "iPhone" or "iPad".
                                         }];
#else
        NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:
                                       @{
                                         MSAL_ID_PLATFORM:@"MSAL.OSX",
                                         MSAL_ID_VERSION:@MSAL_VERSION_STRING,
                                         MSAL_ID_OS_VER:[NSString stringWithFormat:@"%ld.%ld.%ld", (long)osVersion.majorVersion, (long)osVersion.minorVersion, (long)osVersion.patchVersion],
                                         }];
#endif
        NSString* CPUVer = [self getCPUInfo];
        if (![NSString msalIsStringNilOrBlank:CPUVer])
        {
            [result setObject:CPUVer forKey:MSAL_ID_CPU];
        }
        
        msalId = result;
    });
    
    return msalId;
}

- (void)logLevel:(MSALLogLevel)level isPII:(BOOL)isPii context:(id<MSALRequestContext>)context format:(NSString *)format, ...
{
    if (!_callback)
    {
        return;
    }
    
    if (!format)
    {
        return;
    }
    
    if (level > _level)
    {
        return;
    }
    
    if (isPii && !_PiiLoggingEnabled)
    {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString* component = [context component];
    if (component)
    {
        component = [NSString stringWithFormat:@" (%@)", component];
    }
    else
    {
        component = @"";
    }
    
    NSString* correlationId = context.correlationId.UUIDString;
    NSString* correlationIdStr = @"";
    if (correlationId)
    {
        correlationIdStr = [NSString stringWithFormat:@" - %@", correlationId];
    }
    
    NSString* dateString =  [s_dateFormatter stringFromDate:[NSDate date]];
    
    
    NSString* log = [NSString stringWithFormat:@"MSAL " MSAL_VERSION_STRING " %@ [%@%@]%@ %@", s_OSString, dateString, correlationIdStr, component, message];
    
    if (_callback)
    {
        _callback(level, log, isPii);
    }
}

@end
