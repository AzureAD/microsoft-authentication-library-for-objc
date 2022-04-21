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

#import "YKFAccessoryConnectionConfiguration.h"
#import "EAAccessoryManager+Testing.h"


@protocol YKFAccessoryConnectionDelegate <NSObject>

- (void)didConnectAccessory:(YKFAccessoryConnection *_Nonnull)connection;
- (void)didDisconnectAccessory:(YKFAccessoryConnection *_Nonnull)connection error:(NSError *_Nullable)error;

@end

typedef void (^YKFAccessoryConnectionStateChangeBlock)(YKFAccessoryConnectionState, YKFAccessoryConnectionState);

@interface YKFAccessoryConnection()

@property (nonatomic, readonly) YKFAccessoryConnectionState state;
@property(nonatomic, weak) id<YKFAccessoryConnectionDelegate> _Nullable delegate;

/*
 Hidden initializer to avoid the creation of multiple instances outside YubiKit.
 */
- (nullable instancetype)initWithAccessoryManager:(nonnull id<YKFEAAccessoryManagerProtocol>)accessoryManager
                                    configuration:(nonnull YKFAccessoryConnectionConfiguration *)configuration;

@end
