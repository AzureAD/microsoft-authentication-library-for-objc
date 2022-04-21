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

#import <CoreNFC/CoreNFC.h>

#import "YubiKitDeviceCapabilities.h"
#import "YubiKitExternalLocalization.h"

#import "YKFNFCConnectionController.h"
#import "YKFNFCConnection.h"
#import "YKFNFCConnection+Private.h"
#import "YKFBlockMacros.h"
#import "YKFLogger.h"
#import "YKFAssert.h"

#import "YKFSmartCardInterface.h"
#import "YKFNFCOTPSession+Private.h"
#import "YKFU2FSession+Private.h"
#import "YKFFIDO2Session+Private.h"
#import "YKFOATHSession+Private.h"
#import "YKFPIVSession+Private.h"
#import "YKFChallengeResponseSession.h"
#import "YKFChallengeResponseSession+Private.h"
#import "YKFManagementSession.h"
#import "YKFManagementSession+Private.h"
#import "YKFNFCTagDescription+Private.h"

#import "YKFSessionError.h"
#import "YKFSessionError+Private.h"

@interface YKFNFCConnection()<NFCTagReaderSessionDelegate>

@property (nonatomic, readwrite) YKFNFCConnectionState nfcConnectionState;
@property (nonatomic, readwrite) NSError *nfcConnectionError;

@property (nonatomic, readwrite) YKFNFCTagDescription *tagDescription API_AVAILABLE(ios(13.0));

@property (nonatomic) id<YKFConnectionControllerProtocol> connectionController;

@property (nonatomic) NSOperationQueue *communicationQueue;
@property (nonatomic) dispatch_queue_t sharedDispatchQueue;

@property (nonatomic) NFCTagReaderSession *nfcTagReaderSession API_AVAILABLE(ios(13.0));

@property (nonatomic) NSTimer *iso7816NfcTagAvailabilityTimer;

@property (nonatomic, readwrite) id<YKFSessionProtocol> currentSession;

@end

@implementation YKFNFCConnection

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupCommunicationQueue];
    }
    return self;
}

- (YKFNFCConnectionState)state {
    return _nfcConnectionState;
}

- (YKFSmartCardInterface *)smartCardInterface {
    if (!self.connectionController) {
        return nil;
    }
    return [[YKFSmartCardInterface alloc] initWithConnectionController:self.connectionController];
}

- (void)oathSession:(YKFOATHSessionCompletionBlock _Nonnull)callback {
    if (@available(iOS 13.0, *)) {
        [self.currentSession clearSessionState];
        [YKFOATHSession sessionWithConnectionController:self.connectionController
                                                completion:^(YKFOATHSession *_Nullable session, NSError * _Nullable error) {
            self.currentSession = session;
            callback(session, error);
        }];
    }
}

- (void)u2fSession:(YKFU2FSessionCompletionBlock _Nonnull)callback {
    if (@available(iOS 13.0, *)) {
        [self.currentSession clearSessionState];
        [YKFU2FSession sessionWithConnectionController:self.connectionController
                                                completion:^(YKFU2FSession *_Nullable session, NSError * _Nullable error) {
            self.currentSession = session;
            callback(session, error);
        }];
    }
}

- (void)fido2Session:(YKFFIDO2SessionCompletionBlock _Nonnull)callback {
    [self.currentSession clearSessionState];
    [YKFFIDO2Session sessionWithConnectionController:self.connectionController
                                            completion:^(YKFFIDO2Session *_Nullable session, NSError * _Nullable error) {
        self.currentSession = session;
        callback(session, error);
    }];
}

- (void)pivSession:(YKFPIVSessionCompletionBlock _Nonnull)callback {
    [self.currentSession clearSessionState];
    [YKFPIVSession sessionWithConnectionController:self.connectionController
                                        completion:^(YKFPIVSession *_Nullable session, NSError * _Nullable error) {
        self.currentSession = session;
        callback(session, error);
    }];
}

- (void)challengeResponseSession:(YKFChallengeResponseSessionCompletionBlock _Nonnull)callback {
    [self.currentSession clearSessionState];
    [YKFChallengeResponseSession sessionWithConnectionController:self.connectionController
                                                         completion:^(YKFChallengeResponseSession *_Nullable session, NSError * _Nullable error) {
        self.currentSession = session;
        callback(session, error);
    }];
}

- (void)managementSession:(YKFManagementSessionCompletion _Nonnull)callback {
    [self.currentSession clearSessionState];
    [YKFManagementSession sessionWithConnectionController:self.connectionController
                                                  completion:^(YKFManagementSession *_Nullable session, NSError * _Nullable error) {
        self.currentSession = session;
        callback(session, error);
    }];
}

- (void)dealloc {
    if (@available(iOS 13.0, *)) {
        [self unobserveIso7816TagAvailability];
    }
}

#pragma mark - Session lifecycle

- (void)start API_AVAILABLE(ios(13.0)) {
    YKFAssertReturn(YubiKitDeviceCapabilities.supportsISO7816NFCTags, @"Cannot start the NFC session on an unsupported device.");
    
    if (self.nfcTagReaderSession && self.nfcTagReaderSession.isReady) {
        YKFLogInfo(@"NFC session already started. Ignoring start request.");
        return;
    }
    
    NFCTagReaderSession *nfcTagReaderSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:nil];
    nfcTagReaderSession.alertMessage = YubiKitExternalLocalization.nfcScanAlertMessage;
    [nfcTagReaderSession beginSession];
}

- (void)stop API_AVAILABLE(ios(13.0)) {
    if (!self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session already stopped. Ignoring stop request.");
        return;
    }
    
    [self setAlertMessage:YubiKitExternalLocalization.nfcScanSuccessAlertMessage];
    [self updateServicesForSession:self.nfcTagReaderSession tag:nil state:YKFNFCConnectionStateClosed errorMessage:nil];
}

- (void)stopWithMessage:(NSString *)message API_AVAILABLE(ios(13.0)) {
    if (!self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session already stopped. Ignoring stop request.");
        return;
    }
    
    [self setAlertMessage:message];
    [self updateServicesForSession:self.nfcTagReaderSession tag:nil state:YKFNFCConnectionStateClosed errorMessage:nil];
}

- (void)stopWithErrorMessage:(NSString *)errorMessage API_AVAILABLE(ios(13.0)) {
    if (!self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session already stopped. Ignoring stop request.");
        return;
    }
    
    [self updateServicesForSession:self.nfcTagReaderSession tag:nil state:YKFNFCConnectionStateClosed errorMessage:errorMessage];
}


- (void)cancelCommands API_AVAILABLE(ios(13.0)) {
    [self.connectionController cancelAllCommands];
}

#pragma mark - Alert customization

- (void)setAlertMessage:(NSString*) alertMessage API_AVAILABLE(ios(13.0))  {
    if (!self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session is not started.");
        return;
    }

    self.nfcTagReaderSession.alertMessage = alertMessage;
}


#pragma mark - Shared communication queue

- (void)setupCommunicationQueue {
    // Create a sequential queue because the YubiKey accepts sequential commands.
    self.communicationQueue = [[NSOperationQueue alloc] init];
    self.communicationQueue.maxConcurrentOperationCount = 1;
    
    dispatch_queue_attr_t dispatchQueueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, -1);
    self.sharedDispatchQueue = dispatch_queue_create("com.yubico.YKCOMNFC", dispatchQueueAttributes);
    
    self.communicationQueue.underlyingQueue = self.sharedDispatchQueue;
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    YKFLogNSError(error);
    [self updateServicesForSession:session error: error];
}

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session API_AVAILABLE(ios(13.0)) {
    YKFLogInfo(@"NFC session did become active.");
    self.nfcTagReaderSession = session;
    [self updateServicesForSession:session tag:nil state:YKFNFCConnectionStatePolling errorMessage:nil];
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags API_AVAILABLE(ios(13.0)) {
    YKFLogInfo(@"NFC session did detect tags.");
    
    if (!tags.count) {
        YKFLogInfo(@"No tags found");
        [self.nfcTagReaderSession restartPolling];
        return;
    }
    id<NFCISO7816Tag> activeTag = nil;
    for (id<NFCTag> tag in tags) {
        if (tag.type == NFCTagTypeISO7816Compatible) {
            activeTag = [tag asNFCISO7816Tag];
            break;
        }
    }
    if (!activeTag) {
        YKFLogInfo(@"No ISO-7816 compatible tags found");
        [self.nfcTagReaderSession restartPolling];
        return;
    }
    
    ykf_weak_self();
    [self.nfcTagReaderSession connectToTag:activeTag completionHandler:^(NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            // don't close session if tag was invalid or connection to tag had an error
            // this session can be reused for another tag
            YKFLogNSError(error);
            [self.nfcTagReaderSession restartPolling];
            return;
        }
        
        YKFLogInfo(@"NFC session did connect to tag.");
        [strongSelf updateServicesForSession:session tag:activeTag state:YKFNFCConnectionStateOpen errorMessage:nil];
    }];
}

#pragma mark - Helpers
- (void)updateServicesForSession:(NFCTagReaderSession *)session error:(NSError *)error API_AVAILABLE(ios(13.0)) {
    // if the session was already closed ignore the error
    if (self.nfcConnectionState == YKFNFCConnectionStateClosed) {
        return;
    }
    
    // if error was received for another session that is not currently active we can ignore it
    if (self.nfcTagReaderSession != session) {
        return;
    }

    self.nfcConnectionError = error;
    [self.nfcTagReaderSession invalidateSessionWithErrorMessage:error.localizedDescription];
    [self updateServicesForSession:session tag:nil state:YKFNFCConnectionStateClosed errorMessage:nil];
}

- (void)updateServicesForSession:(NFCTagReaderSession *)session tag:(id<NFCISO7816Tag>)tag state:(YKFNFCConnectionState)state errorMessage:(NSString *)errorMessage API_AVAILABLE(ios(13.0)) {
    if (self.nfcConnectionState == state) {
        return;
    }
    if (self.nfcTagReaderSession != session) {
        return;
    }
    
    YKFNFCConnectionState previousState = self.nfcConnectionState;
    self.nfcConnectionState = state;

    switch (state) {
        case YKFNFCConnectionStateClosed:
            if (previousState == YKFNFCConnectionStateOpen) {
                [self.delegate didDisconnectNFC:self error:self.nfcConnectionError];
            } else {
                 [self.delegate didFailConnectingNFC:self.nfcConnectionError];
            }
            self.connectionController = nil;
            self.tagDescription = nil;

            [self unobserveIso7816TagAvailability];

            // invalidating session closes nfc reading sheet
            if (errorMessage) {
                [self.nfcTagReaderSession invalidateSessionWithErrorMessage:errorMessage];
            } else {
                [self.nfcTagReaderSession invalidateSession];
            }
            self.nfcTagReaderSession = nil;
            break;
        
        case YKFNFCConnectionStatePolling:
            self.nfcConnectionError = nil;
            self.connectionController = nil;
            self.tagDescription = nil;
            [self unobserveIso7816TagAvailability];
            
            [self.nfcTagReaderSession restartPolling];
            break;
            
        case YKFNFCConnectionStateOpen:
            [self observeIso7816TagAvailability];
            
            self.connectionController = [[YKFNFCConnectionController alloc] initWithNFCTag:tag operationQueue:self.communicationQueue];
            [self.delegate didConnectNFC:self];
            
            self.tagDescription = [[YKFNFCTagDescription alloc] initWithTag: tag];
            break;
    }
    
}

#pragma mark - Tag availability observation

- (void)observeIso7816TagAvailability API_AVAILABLE(ios(13.0)) {
    // Note: A timer is used because the "available" property is not KVO observable and the tag has no delegate.
    // This solution is suboptimal but in line with some examples from Apple using a dispatch queue.
    ykf_weak_self();
    self.iso7816NfcTagAvailabilityTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:0.5 repeats:YES block:^(NSTimer *timer) {
        ykf_safe_strong_self();
        BOOL available = strongSelf.nfcTagReaderSession.connectedTag.available;
        if (available) {
            YKFLogVerbose(@"NFC tag is available.");
        } else {
            YKFLogInfo(@"NFC tag is no longer available.");
            // moving from state of open back to polling/waiting for new tag
            [strongSelf updateServicesForSession:strongSelf.nfcTagReaderSession tag:nil state:YKFNFCConnectionStatePolling errorMessage:nil];
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.iso7816NfcTagAvailabilityTimer forMode:NSDefaultRunLoopMode];
}

- (void)unobserveIso7816TagAvailability API_AVAILABLE(ios(13.0)) {
    // Note: A timer is used because the "available" property is not KVO observable and the tag has no delegate.
    // This solution is suboptimal but in line with some examples from Apple using a dispatch queue.
    [self.iso7816NfcTagAvailabilityTimer invalidate];
    self.iso7816NfcTagAvailabilityTimer = nil;
}

@end
