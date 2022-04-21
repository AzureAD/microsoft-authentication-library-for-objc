// Copyright 2018-2021 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "YKFVersion.h"

@interface YKFVersion()

@property (nonatomic, readwrite) UInt8 major;
@property (nonatomic, readwrite) UInt8 minor;
@property (nonatomic, readwrite) UInt8 micro;

@end

@implementation YKFVersion

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        UInt8 *bytes = (UInt8 *)data.bytes;
        self.major = bytes[0];
        self.minor = bytes[1];
        self.micro = bytes[2];
    }
    return self;
}

- (instancetype)initWithBytes:(UInt8)major minor:(UInt8)minor micro:(UInt8)micro {
    self = [super init];
    if (self) {
        self.major = major;
        self.minor = minor;
        self.micro = micro;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)versionString {
    self = [super init];
    if (self) {
        NSArray *versions = [versionString componentsSeparatedByString:@"."];
        if (versions.count != 3) {
            [NSException raise:@"Malformed version string" format:@"%@ is not a valid version string", versionString];
        }
        self.major = [versions[0] intValue];
        self.minor = [versions[1] intValue];
        self.micro = [versions[2] intValue];
    }
    return self;
}

- (NSComparisonResult)compare:(YKFVersion *)version {
    NSComparisonResult majorResult = [[NSNumber numberWithUnsignedShort:self.major] compare:[NSNumber numberWithUnsignedShort:version.major]];
    if (majorResult != NSOrderedSame) {
        return majorResult;
    }
    NSComparisonResult minorResult = [[NSNumber numberWithUnsignedShort:self.minor] compare:[NSNumber numberWithUnsignedShort:version.minor]];
    if (minorResult != NSOrderedSame) {
        return minorResult;
    }
    return [[NSNumber numberWithUnsignedShort:self.micro] compare:[NSNumber numberWithUnsignedShort:version.micro]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%i.%i.%i", self.major, self.minor, self.micro];
}

@end
