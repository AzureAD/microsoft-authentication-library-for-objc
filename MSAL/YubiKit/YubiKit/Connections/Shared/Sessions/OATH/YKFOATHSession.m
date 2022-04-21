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

#import "YKFOATHSession.h"
#import "YKFOATHSession+Private.h"
#import "YKFSession+Private.h"
#import "YKFAccessoryConnectionController.h"
#import "YKFOATHError.h"
#import "YKFAPDUError.h"
#import "YKFLogger.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "YKFSelectOATHApplicationAPDU.h"
#import "YKFOATHSendRemainingAPDU.h"
#import "YKFOATHSetPasswordAPDU.h"
#import "YKFOATHUnlockAPDU.h"

#import "YKFSessionError+Private.h"

#import "YKFNSDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"
#import "YKFNSMutableDataAdditions.h"
#import "TKTLVRecordAdditions+Private.h"

#import "YKFAPDU+Private.h"

#import "YKFOATHPutAPDU.h"
#import "YKFOATHDeleteAPDU.h"
#import "YKFOATHRenameAPDU.h"
#import "YKFOATHCalculateAPDU.h"
#import "YKFOATHCalculateAllAPDU.h"

#import "YKFOATHCalculateAllResponse.h"
#import "YKFOATHCalculateAllResponse.h"
#import "YKFOATHCode+Private.h"
#import "YKFOATHCode.h"
#import "YKFOATHCredentialUtils.h"
#import "YKFOATHCredentialTemplate.h"
#import "YKFOATHListResponse.h"
#import "YKFOATHSelectApplicationResponse.h"
#import "YKFOATHSelectApplicationResponse.h"
#import "YKFOATHUnlockResponse.h"

#import "YKFSmartCardInterface.h"
#import "YKFSelectApplicationAPDU.h"

static const NSUInteger YKFOATHResponseTag = 0x75;
static const NSUInteger YKFOATHCredentialIdTag = 0x71;
static const NSUInteger YKFOATHChallengeTag = 0x74;
static const NSUInteger YKFOATHCalculateIns = 0xa2;

static const NSTimeInterval YKFOATHServiceTimeoutThreshold = 10; // seconds

typedef void (^YKFOATHServiceResultCompletionBlock)(NSData* _Nullable  result, NSError* _Nullable error);

@interface YKFOATHSession()

/*
 In case of OATH, the reselection of the application leads to the loss of authentication (if any). To avoid
 this the select application response is cached to avoid reselecting the applet. If the request fails with
 timeout the cache gets invalidated to allow again the following requests to select the application again.
 */
@property (nonatomic) YKFOATHSelectApplicationResponse *cachedSelectApplicationResponse;
@property (nonatomic, readonly) BOOL isValid;

@end

@implementation YKFOATHSession

- (BOOL)isValid {
    return self.cachedSelectApplicationResponse != nil;
}

+ (void)sessionWithConnectionController:(nonnull id<YKFConnectionControllerProtocol>)connectionController
                               completion:(YKFOATHSessionCompletion _Nonnull)completion {
    YKFOATHSession *session = [YKFOATHSession new];
    session.smartCardInterface = [[YKFSmartCardInterface alloc] initWithConnectionController:connectionController];
    
    YKFSelectApplicationAPDU *apdu = [[YKFSelectApplicationAPDU alloc] initWithApplicationName:YKFSelectApplicationAPDUNameOATH];
    [session.smartCardInterface selectApplication:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else {
            session.cachedSelectApplicationResponse = [[YKFOATHSelectApplicationResponse alloc] initWithResponseData:data];
            completion(session, nil);
        }
    }];
}

-(YKFVersion *)version {
    return _cachedSelectApplicationResponse.version;
}

#pragma mark - Credential Add/Delete

- (void)putCredentialTemplate:(YKFOATHCredentialTemplate *)credentialTemplate requiresTouch:(BOOL)requiresTouch completion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(credentialTemplate);
    YKFParameterAssertReturn(completion);
    
    YKFSessionError *credentialError = [YKFOATHCredentialUtils validateCredentialTemplate:credentialTemplate];
    if (credentialError) {
        completion(credentialError);
        return;
    }
    
    YKFOATHPutAPDU *apdu = [[YKFOATHPutAPDU alloc] initWithCredentialTemplate:credentialTemplate requriesTouch:requiresTouch];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        // No result except status code
        completion(error);
    }];
}

- (void)deleteCredential:(YKFOATHCredential *)credential completion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(credential);
    YKFParameterAssertReturn(completion);

    YKFSessionError *credentialError = [YKFOATHCredentialUtils validateCredential:credential];
    if (credentialError) {
        completion(credentialError);
        return;
    }

    YKFOATHDeleteAPDU *apdu = [[YKFOATHDeleteAPDU alloc] initWithCredential:credential];
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        // No result except status code
        completion(error);
    }];
}

- (void)renameCredential:(nonnull YKFOATHCredential *)credential
               newIssuer:(nonnull NSString*)newIssuer
              newAccount:(nonnull NSString*)newAccount
              completion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(credential);
    YKFParameterAssertReturn(newIssuer);
    YKFParameterAssertReturn(newAccount);
    YKFParameterAssertReturn(completion);
    
    YKFSessionError *credentialError = [YKFOATHCredentialUtils validateCredential:credential];
    if (credentialError) {
        completion(credentialError);
        return;
    }
    
    YKFOATHCredential *renamedCredential = credential.copy;
    renamedCredential.issuer = newIssuer;
    renamedCredential.accountName = newAccount;
    
    YKFSessionError *renamedCredentialError = [YKFOATHCredentialUtils validateCredential:renamedCredential];
    if (renamedCredentialError) {
        completion(renamedCredentialError);
        return;
    }
    
    YKFAPDU *apdu = [[YKFOATHRenameAPDU alloc] initWithCredential:credential renamedCredential:renamedCredential];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        // No result except status code
        completion(error);
    }];
}

#pragma mark - Credential Calculation

- (void)calculateCredential:(YKFOATHCredential *)credential completion:(YKFOATHSessionCalculateCompletionBlock)completion {
    NSDate *timestamp = [NSDate date];
    [self calculateCredential:credential timestamp:timestamp completion:completion];
}

- (void)calculateCredential:(YKFOATHCredential *)credential timestamp:(NSDate *)timestamp completion:(YKFOATHSessionCalculateCompletionBlock)completion {
    YKFParameterAssertReturn(credential);
    YKFParameterAssertReturn(completion);
    YKFParameterAssertReturn(timestamp);

    YKFSessionError *credentialError = [YKFOATHCredentialUtils validateCredential:credential];
    if (credentialError) {
        completion(nil, credentialError);
        return;
    }
    
    YKFAPDU *apdu = [[YKFOATHCalculateAPDU alloc] initWithCredential:credential timestamp:timestamp];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        YKFOATHCode *code = [[YKFOATHCode alloc] initWithKeyResponseData:result
                                                         requestTimetamp:timestamp
                                                           requestPeriod:credential.period];
        if (!code) {
            completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeBadCalculationResponse]);
            return;
        }
        completion(code, nil);
    }];
}


- (void)calculateAllWithCompletion:(YKFOATHSessionCalculateAllCompletionBlock)completion {
    NSDate *timestamp = [NSDate date];
    [self calculateAllWithTimestamp:timestamp completion:completion];
}

- (void)calculateAllWithTimestamp:(NSDate *)timestamp completion:(YKFOATHSessionCalculateAllCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFAPDU *apdu = [[YKFOATHCalculateAllAPDU alloc] initWithTimestamp:timestamp];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        YKFOATHCalculateAllResponse *response = [[YKFOATHCalculateAllResponse alloc] initWithKeyResponseData:result
                                                                                             requestTimetamp:timestamp];
        if (!response) {
            completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeBadCalculateAllResponse]);
            return;
        }
        completion(response.credentials, nil);
    }];
}

#pragma mark - Credential Listing

- (void)listCredentialsWithCompletion:(YKFOATHSessionListCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0x00 ins:0xA1 p1:0x00 p2:0x00 data:[NSData data] type:YKFAPDUTypeShort];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        YKFOATHListResponse *response = [[YKFOATHListResponse alloc] initWithKeyResponseData:result];
        if (!response) {
            completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeBadListResponse]);
            return;
        }
        
        completion(response.credentials, nil);
    }];
}

#pragma mark - Reset

- (void)resetWithCompletion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    if (!self.isValid) {
        completion([YKFSessionError errorWithCode:YKFSessionErrorInvalidSessionStateStatusCode]);
        return;
    }
    
    self.cachedSelectApplicationResponse = nil;
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0x00 ins:0x04 p1:0xDE p2:0xAD data:[NSData data] type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (!error) {
            YKFSelectApplicationAPDU *apdu = [[YKFSelectApplicationAPDU alloc] initWithApplicationName:YKFSelectApplicationAPDUNameOATH];
            [self.smartCardInterface selectApplication:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
                if (error) {
                    completion(error);
                } else {
                    self.cachedSelectApplicationResponse = [[YKFOATHSelectApplicationResponse alloc] initWithResponseData:data];
                    completion(nil);
                }
            }];
        } else {
            completion(error);
        }
    }];
}

#pragma mark - OATH Authentication

- (void)setPassword:(NSString *)password completion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(password);
    YKFParameterAssertReturn(completion);
    // Check if the session is valid since we need the cached select application response later
    if (!self.isValid) {
        completion([YKFSessionError errorWithCode:YKFSessionErrorInvalidSessionStateStatusCode]);
        return;
    }
    // Build the request APDU with the select ID salt
    YKFOATHSetPasswordAPDU *apdu = [[YKFOATHSetPasswordAPDU alloc] initWithPassword:password salt:self.cachedSelectApplicationResponse.selectID];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            if (error.code == YKFAPDUErrorCodeAuthenticationRequired) {
                completion([YKFOATHError errorWithCode:YKFOATHErrorCodeAuthenticationRequired]);
            } else {
                completion(error);
            }
        } else {
            completion(nil);
        }
    }];
}

- (void)unlockWithPassword:(NSString *)password completion:(YKFOATHSessionGenericCompletionBlock)completion {
    YKFParameterAssertReturn(password);
    YKFParameterAssertReturn(completion);
    if (!self.isValid) {
        completion([YKFSessionError errorWithCode:YKFSessionErrorInvalidSessionStateStatusCode]);
        return;
    }
    YKFOATHUnlockAPDU *apdu = [[YKFOATHUnlockAPDU alloc] initWithPassword:password challenge:self.cachedSelectApplicationResponse.challenge salt:self.cachedSelectApplicationResponse.selectID];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            if (error.code == YKFAPDUErrorCodeWrongData) {
                completion([YKFOATHError errorWithCode:YKFOATHErrorCodeWrongPassword]);
            } else {
                completion(error);
            }
            return;
        }
        
        YKFOATHUnlockResponse *unlockResponse = [[YKFOATHUnlockResponse alloc] initWithResponseData:data];
        if (!unlockResponse) {
            completion([YKFOATHError errorWithCode:YKFOATHErrorCodeBadValidationResponse]);
            return;
        }
        NSData *expectedApduData = apdu.expectedChallengeData;
        if (![unlockResponse.response isEqualToData:expectedApduData]) {
            completion([YKFOATHError errorWithCode:YKFOATHErrorCodeBadValidationResponse]);
            return;
        }
        
        completion(nil);
    }];
}

- (void)calculateResponseForCredentialID:(NSData *)credentialId challenge:(NSData *)challenge completion:(YKFOATHSessionCalculateResponseCompletionBlock)completion {
    YKFParameterAssertReturn(credentialId);
    YKFParameterAssertReturn(challenge);
    YKFParameterAssertReturn(completion);

    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:[[YKFTLVRecord alloc] initWithTag:YKFOATHCredentialIdTag value:credentialId].data];
    [data appendData:[[YKFTLVRecord alloc] initWithTag:YKFOATHChallengeTag value:challenge].data];
    
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFOATHCalculateIns p1:0 p2:0 data:data type:YKFAPDUTypeShort];
    
    [self executeOATHCommand:apdu completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        YKFTLVRecord *responseRecord = [YKFTLVRecord recordFromData:result];

        if (responseRecord.tag != YKFOATHResponseTag || responseRecord.value.length == 0) {
            completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeBadCalculationResponse]);
            return;
        }
        NSRange range = NSMakeRange(1, [responseRecord.value length] - 1);
        NSData *response = [responseRecord.value subdataWithRange:range];
        
        completion(response, nil);
    }];
}

#pragma mark - Request Execution

- (void)executeOATHCommand:(YKFAPDU *)apdu completion:(YKFOATHServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(apdu);
    YKFParameterAssertReturn(completion);
    if (!self.isValid) {
        completion(nil, [YKFSessionError errorWithCode:YKFSessionErrorInvalidSessionStateStatusCode]);
        return;
    }
    
    NSDate *startTime = [NSDate date];
    [self.smartCardInterface executeCommand:apdu sendRemainingIns:YKFSmartCardInterfaceSendRemainingInsOATH completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (data) {
            completion(data, nil);
            return;
        }
        NSTimeInterval executionTime = -[startTime timeIntervalSinceNow];
        switch(error.code) {
            case YKFAPDUErrorCodeAuthenticationRequired:
                if (executionTime < YKFOATHServiceTimeoutThreshold) {
                    completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeAuthenticationRequired]);
                } else {
                    completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeTouchTimeout]);
                }
                break;
            case YKFAPDUErrorCodeDataInvalid:
                completion(nil, [YKFOATHError errorWithCode:YKFOATHErrorCodeNoSuchObject]);
                break;
            default: {
                completion(nil, error);
            }
        }
    }];
}

#pragma mark - YKFSessionProtocol

- (void)clearSessionState {
    self.cachedSelectApplicationResponse = nil;
}

#pragma mark - Test Helpers

- (void)invalidateApplicationSelectionCache {
    self.cachedSelectApplicationResponse = nil;
}

@end
