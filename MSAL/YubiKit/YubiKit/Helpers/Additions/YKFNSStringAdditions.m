// Copyright 2018-2019 Yubico AB
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

#import "YKFNSStringAdditions.h"

@implementation NSString(NSString_OATH)

- (void)ykf_OATHKeyExtractPeriod:(NSUInteger *)period issuer:(NSString **)issuer account:(NSString **)account label:(NSString **)label {
    NSString *key = self;
    NSMutableArray *componentsArray;

    // TOTP key with format [period]/[label]
    if ([key containsString:@"/"]) {
        NSArray *stringComponents = [key componentsSeparatedByString:@"/"];
        if (stringComponents.count > 1) {
            NSUInteger interval = [stringComponents[0] intValue];
            if (interval) {
                *period = interval;

                componentsArray = [NSMutableArray arrayWithArray: stringComponents];
                [componentsArray removeObjectAtIndex: 0];
                key = [componentsArray componentsJoinedByString: @"/"];
            }
        }
    }
    
    *label = key;
    
    // Parse the label as [issuer]:[account]
    if ([key containsString: @":"]) {
        NSArray *labelComponents = [key componentsSeparatedByString:@":"];
        *account = labelComponents.lastObject;

        componentsArray = [NSMutableArray arrayWithArray: labelComponents];
        [componentsArray removeLastObject];
        *issuer = [componentsArray componentsJoinedByString: @":"];
    } else {
        *account = key;
    }
}

@end
