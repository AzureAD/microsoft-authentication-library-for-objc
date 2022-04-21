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

#import <Foundation/Foundation.h>
#import "YKFManagementSessionFeatures.h"
#import "YKFFeature.h"

@interface YKFManagementSessionFeatures()
@property (nonatomic, readwrite) YKFFeature * _Nonnull deviceInfo;
@property (nonatomic, readwrite) YKFFeature * _Nonnull deviceConfig;
@end

@implementation YKFManagementSessionFeatures

- (instancetype)init {
    self = [super init];
    if (self) {
        self.deviceInfo = [[YKFFeature alloc] initWithName:@"Device info" versionString:@"4.1.0"];
        self.deviceConfig = [[YKFFeature alloc] initWithName:@"Device config" versionString:@"5.0.0"];
    }
    return self;
}

@end
