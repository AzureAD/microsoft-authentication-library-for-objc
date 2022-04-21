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

#import <ExternalAccessory/ExternalAccessory.h>

#import "YubiKitManager.h"
#import "YKFAccessoryConnectionConfiguration.h"

#import "YKFNFCOTPSession+Private.h"
#import "YKFAccessoryConnection+Private.h"
#import "YKFNFCConnection+Private.h"

@interface YubiKitManager()<YKFAccessoryConnectionDelegate, YKFNFCConnectionDelegate>

@property (nonatomic, readwrite) YKFNFCConnection *nfcConnection;
@property (nonatomic, readwrite) YKFAccessoryConnection *accessoryConnection;
@property (nonatomic, readwrite) YKFNFCOTPSession *otpSession;

@end

@implementation YubiKitManager

__weak id<YKFManagerDelegate> _delegate;

static YubiKitManager *sharedInstance;

+ (YubiKitManager *)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YubiKitManager alloc] initOnce];
    });
    return sharedInstance;
}

- (instancetype)initOnce {
    self = [super init];
    if (self) {
        if (@available(iOS 11, *)) {
            YKFNFCConnection *nfcConnection = [[YKFNFCConnection alloc] init];
            nfcConnection.delegate = self;
            self.nfcConnection = nfcConnection;
        }
       
        YKFAccessoryConnectionConfiguration *configuration = [[YKFAccessoryConnectionConfiguration alloc] init];
        EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
        YKFAccessoryConnection *accessoryConnection = [[YKFAccessoryConnection alloc] initWithAccessoryManager:accessoryManager configuration:configuration];
        accessoryConnection.delegate = self;
        self.accessoryConnection = accessoryConnection;
        
        if (@available(iOS 11.0, *)) {
            self.otpSession = [[YKFNFCOTPSession alloc] initWithTokenParser:nil session:nil];
        }
    }
    return self;
}

- (void)setDelegate:(id<YKFManagerDelegate>)delegate {
    _delegate = delegate;
    if (self.accessoryConnection.state == YKFAccessoryConnectionStateOpen) {
        [self.delegate didConnectAccessory:self.accessoryConnection];
    } else if (self.nfcConnection.state == YKFNFCConnectionStateOpen) {
        [self.delegate didConnectNFC:self.nfcConnection];
    }
}

-(id<YKFManagerDelegate>)delegate {
    return _delegate;
}

- (void)startAccessoryConnection {
    [self.accessoryConnection start];
}

- (void)stopAccessoryConnection {
    [self.accessoryConnection stop];
}

- (void)startNFCConnection API_AVAILABLE(ios(13.0)) {
    [self.nfcConnection start];
}

- (void)stopNFCConnection API_AVAILABLE(ios(13.0)) {
    [self.nfcConnection stop];
}

- (void)stopNFCConnectionWithMessage:(NSString *_Nonnull)message API_AVAILABLE(ios(13.0)) {
    [self.nfcConnection stopWithMessage:message];
}

- (void)stopNFCConnectionWithErrorMessage:(NSString *_Nonnull)errorMessage API_AVAILABLE(ios(13.0)) {
    [self.nfcConnection stopWithErrorMessage:errorMessage];
}


- (void)didConnectAccessory:(YKFAccessoryConnection *_Nonnull)connection {
    [self.delegate didConnectAccessory:connection];
}

- (void)didDisconnectAccessory:(YKFAccessoryConnection *_Nonnull)connection error:(NSError * _Nullable)error {
    [self.delegate didDisconnectAccessory:connection error:error];
}


- (void)didConnectNFC:(YKFNFCConnection *_Nonnull)connection {
    [self.delegate didConnectNFC:connection];
}

- (void)didDisconnectNFC:(YKFNFCConnection *_Nonnull)connection error:(NSError * _Nullable)error {
    [self.delegate didDisconnectNFC:connection error:error];
}

- (void)didFailConnectingNFC:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(didFailConnectingNFC:)]) {
        [self.delegate didFailConnectingNFC:error];
    }
}

@end
