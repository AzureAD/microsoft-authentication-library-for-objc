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

#import <Foundation/Foundation.h>
#import "YKFRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^YKFSessionCommandBlock)(void);

@interface YKFSession: NSObject

/// @abstract Dispatch a code block for execution once all currently scheduled commands have completed.
/// @param block The block that gets called.
- (void)dispatchAfterCurrentCommands:(YKFSessionCommandBlock)block NS_SWIFT_NAME(dispatchAfterCurrentCommands(block:));

@end

NS_ASSUME_NONNULL_END
