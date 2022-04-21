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

#import "YKFU2FSession.h"
#import "YKFSession+Private.h"
#import "YKFAccessoryConnectionController.h"
#import "YKFU2FError.h"
#import "YKFAPDUError.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "YKFSessionError+Private.h"
#import "YKFU2FSession+Private.h"
#import "YKFU2FSignResponse.h"
#import "YKFU2FRegisterResponse.h"

#import "YKFU2FRegisterAPDU.h"
#import "YKFU2FSignAPDU.h"

#import "YKFU2FRegisterResponse+Private.h"
#import "YKFU2FSignResponse+Private.h"
#import "YKFAPDU+Private.h"

#import "YKFSmartCardInterface.h"
#import "YKFSelectApplicationAPDU.h"

typedef void (^YKFU2FServiceResultCompletionBlock)(NSData* _Nullable  result, NSError* _Nullable error);

NSString* const YKFU2FServiceProtocolKeyStatePropertyKey = @"keyState";

static const int YKFU2FMaxRetries = 30; // times
static const NSTimeInterval YKFU2FRetryTimeInterval = 0.5; // seconds

@interface YKFU2FSession()

@property (nonatomic, assign, readwrite) YKFU2FSessionKeyState keyState;

@end

@implementation YKFU2FSession

+ (void)sessionWithConnectionController:(nonnull id<YKFConnectionControllerProtocol>)connectionController
                               completion:(YKFU2FSessionCompletion _Nonnull)completion {
    YKFU2FSession *session = [YKFU2FSession new];
    session.smartCardInterface = [[YKFSmartCardInterface alloc] initWithConnectionController:connectionController];
    
    YKFSelectApplicationAPDU *apdu = [[YKFSelectApplicationAPDU alloc] initWithApplicationName:YKFSelectApplicationAPDUNameU2F];
    [session.smartCardInterface selectApplication:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else {
            completion(session, nil);
        }
    }];
}

- (void)clearSessionState {}

#pragma mark - Key State

- (void)updateKeyState:(YKFU2FSessionKeyState)keyState {
    if (self.keyState == keyState) {
        return;
    }
    self.keyState = keyState;
}

#pragma mark - U2F Register

- (void)registerWithChallenge:(NSString *)challenge appId:(NSString *)appId completion:(YKFU2FSessionRegisterCompletionBlock)completion {
    YKFParameterAssertReturn(challenge);
    YKFParameterAssertReturn(appId);
    YKFParameterAssertReturn(completion);

    YKFU2FRegisterAPDU *apdu = [[YKFU2FRegisterAPDU alloc] initWithChallenge:challenge appId:appId];
    ykf_weak_self();
    [self executeU2FCommand:apdu retryCount:0 completion:^(NSData *result, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        YKFU2FRegisterResponse *registerResponse = [strongSelf processRegisterData:result clientData:apdu.clientData];
        completion(registerResponse, nil);
    }];
}

#pragma mark - U2F Sign

- (void)signWithChallenge:(NSString *)challenge
                keyHandle:(NSString *)keyHandle
                    appId:(NSString *)appId
               completion:(YKFU2FSessionSignCompletionBlock)completion {
    YKFParameterAssertReturn(challenge);
    YKFParameterAssertReturn(keyHandle);
    YKFParameterAssertReturn(appId);
    YKFParameterAssertReturn(completion);

    YKFU2FSignAPDU *apdu = [[YKFU2FSignAPDU alloc] initWithChallenge:challenge keyHandle:keyHandle appId:appId];
    
    ykf_weak_self();
    [self executeU2FCommand:apdu retryCount:0 completion:^(NSData *result, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        YKFU2FSignResponse *signResponse = [strongSelf processSignData:result keyHandle:keyHandle clientData:apdu.clientData];
        completion(signResponse, nil);
    }];
}

#pragma mark - Request Execution

- (void)executeU2FCommand:(YKFAPDU *)apdu retryCount:(int)retryCount completion:(YKFU2FServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(apdu);
    YKFParameterAssertReturn(completion);
    
    ykf_weak_self();
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        ykf_safe_strong_self();
        
        if (data) {
            [strongSelf updateKeyState:YYKFU2FSessionKeyStateIdle];
            completion(data, nil);
            return;
        }
        
        switch (error.code) {
            case YKFAPDUErrorCodeConditionNotSatisfied: {
                [strongSelf handleTouchRequired:apdu retryCount:retryCount completion:completion];
            }
            break;
                
            case YKFAPDUErrorCodeWrongData: {
                [strongSelf updateKeyState:YYKFU2FSessionKeyStateIdle];
                YKFSessionError *connectionError = [YKFU2FError errorWithCode:YKFU2FErrorCodeU2FSigningUnavailable];
                completion(nil, connectionError);
            }
            break;

            default: {
                [strongSelf updateKeyState:YYKFU2FSessionKeyStateIdle];
                completion(nil, error);
            }
            break;
        }
    }];
}

#pragma mark - Private

- (void)handleTouchRequired:(YKFAPDU *)apdu retryCount:(int)retryCount completion:(YKFU2FServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    if (retryCount >= YKFU2FMaxRetries) {
        YKFSessionError *timeoutError = [YKFSessionError errorWithCode:YKFSessionErrorTouchTimeoutCode];
        completion(nil, timeoutError);
        
        [self updateKeyState:YYKFU2FSessionKeyStateIdle];
        return;
    }
    
    [self updateKeyState:YKFU2FSessionKeyStateTouchKey];    
    retryCount += 1;
    
    ykf_weak_self();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, YKFU2FRetryTimeInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ykf_safe_strong_self();
        [strongSelf executeU2FCommand:apdu retryCount:retryCount completion:completion];
    });
}

#pragma mark - Key responses

- (YKFU2FSignResponse *)processSignData:(NSData *)data keyHandle:(NSString *)keyHandle clientData:(NSString *)clientData {
    return [[YKFU2FSignResponse alloc] initWithKeyHandle:keyHandle clientData:clientData signature:data];
}

- (YKFU2FRegisterResponse *)processRegisterData:(NSData *)data clientData:(NSString *)clientData {
    return [[YKFU2FRegisterResponse alloc] initWithClientData:clientData registrationData:data];
}

@end
