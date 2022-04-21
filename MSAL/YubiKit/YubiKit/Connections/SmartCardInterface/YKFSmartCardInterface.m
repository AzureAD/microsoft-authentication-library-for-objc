// Copyright 2018-2020 Yubico AB
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
#import "YKFSmartCardInterface.h"
#import "YKFConnectionControllerProtocol.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"
#import "YKFAPDUError.h"


#import "YKFAccessoryConnectionController.h"
#import "YKFSessionError.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"
#import "YKFLogger.h"
#import "YKFAPDUError.h"

#import "YKFAPDU+Private.h"
#import "YKFSessionError+Private.h"

#import "YKFNSDataAdditions+Private.h"
#import "YKFOATHSendRemainingAPDU.h"
#import "YKFSelectApplicationAPDU.h"


static NSTimeInterval const YKFSmartCardInterfaceDefaultTimeout = 10.0;

@interface YKFSmartCardInterface()

@property (nonatomic, readwrite) id<YKFConnectionControllerProtocol> connectionController;

- (NSData *)dataFromKeyResponse:(NSData *)response;
- (UInt16)statusCodeFromKeyResponse:(NSData *)response;

@end

@implementation YKFSmartCardInterface

-(instancetype)initWithConnectionController:(id<YKFConnectionControllerProtocol>)connectionController {
    self = [super init];
    if (self) {
        self.connectionController = connectionController;
    }
    return self;
}

- (void)selectApplication:(YKFSelectApplicationAPDU *)apdu completion:(YKFSmartCardInterfaceResponseBlock)completion {
    [self.connectionController execute:apdu completion:^(NSData *response, NSError *error, NSTimeInterval executionTime) {
        if (error) {
            completion(nil, error);
            return;
        }
        UInt16 statusCode = [self statusCodeFromKeyResponse:response];
        NSData *data = [self dataFromKeyResponse:response];
        if (statusCode == YKFAPDUErrorCodeNoError) {
            completion(data, nil);
        } else if (statusCode == YKFAPDUErrorCodeMissingFile || statusCode == YKFAPDUErrorCodeInsNotSupported) {
            NSError *error = [YKFSessionError errorWithCode:YKFSessionErrorMissingApplicationCode];
            completion(nil, error);
        } else {
            NSAssert(TRUE, @"The key returned an unexpected SW when selecting application");
            NSError *error = [YKFSessionError errorWithCode:YKFSessionErrorUnexpectedStatusCode];
            completion(nil, error);
        }
    }];
}

- (void)executeCommand:(YKFAPDU *)apdu sendRemainingIns:(YKFSmartCardInterfaceSendRemainingIns)sendRemainingIns  timeout:(NSTimeInterval)timeout data:(NSMutableData *)data completion:(YKFSmartCardInterfaceResponseBlock)completion {
    [self.connectionController execute:apdu
                         timeout:timeout
                            completion:^(NSData *response, NSError *error, NSTimeInterval executionTime) {
        if (error) {
            completion(nil, error);
            return;
        }

        [data appendData:[self dataFromKeyResponse:response]];
        UInt16 statusCode = [self statusCodeFromKeyResponse:response];
        
        if (statusCode >> 8 == YKFAPDUErrorCodeMoreData) {
            YKFLogInfo(@"Key has more data to send. Requesting for remaining data...");
            UInt16 ins;
            switch (sendRemainingIns) {
                case YKFSmartCardInterfaceSendRemainingInsNormal:
                    ins = 0xC0;
                    break;
                case YKFSmartCardInterfaceSendRemainingInsOATH:
                    ins = 0xA5;
                    break;
            }
            YKFAPDU *sendRemainingApdu = [[YKFAPDU alloc] initWithData:[NSData dataWithBytes:(unsigned char[]){0x00, ins, 0x00, 0x00} length:4]];
            // Queue a new request recursively
            [self executeCommand:sendRemainingApdu sendRemainingIns:sendRemainingIns timeout:timeout data:data completion:completion];
            return;
        } else if (statusCode == 0x9000) {
            completion(data, nil);
            return;
        } else {
            YKFSessionError *error = [YKFSessionError errorWithCode:statusCode];
            completion(nil, error);
        }
    }];
}

- (void)executeCommand:(YKFAPDU *)apdu completion:(YKFSmartCardInterfaceResponseBlock)completion {
    [self executeCommand:apdu sendRemainingIns:YKFSmartCardInterfaceSendRemainingInsNormal timeout:YKFSmartCardInterfaceDefaultTimeout completion:completion];
}

- (void)executeCommand:(YKFAPDU *)apdu timeout:(NSTimeInterval)timeout completion:(YKFSmartCardInterfaceResponseBlock)completion {
    [self executeCommand:apdu sendRemainingIns:YKFSmartCardInterfaceSendRemainingInsNormal timeout:timeout completion:completion];
}

- (void)executeCommand:(YKFAPDU *)apdu sendRemainingIns:(YKFSmartCardInterfaceSendRemainingIns)sendRemainingIns completion:(YKFSmartCardInterfaceResponseBlock)completion {
    [self executeCommand:apdu sendRemainingIns:sendRemainingIns timeout:YKFSmartCardInterfaceDefaultTimeout completion:completion];
}

- (void)executeCommand:(YKFAPDU *)apdu sendRemainingIns:(YKFSmartCardInterfaceSendRemainingIns)sendRemainingIns timeout:(NSTimeInterval)timeout completion:(YKFSmartCardInterfaceResponseBlock)completion {
    YKFParameterAssertReturn(apdu);
    YKFParameterAssertReturn(completion);
    NSMutableData *data = [NSMutableData new];
    [self executeCommand:apdu sendRemainingIns:sendRemainingIns timeout:timeout data:data completion:completion];
}

- (void)dispatchAfterCurrentCommands:(YKFSmartCardInterfaceCommandBlock)block {
    [self.connectionController dispatchBlockOnCommunicationQueue:^(NSOperation *operation) {
        // Return if operation is cancelled
        if (operation.isCancelled) {
            return;
        }
        block();
    }];
}

#pragma mark - Helpers

- (NSData *)dataFromKeyResponse:(NSData *)response {
    YKFParameterAssertReturnValue(response, [NSData data]);
    YKFAssertReturnValue(response.length >= 2, @"Key response data is too short.", [NSData data]);
    
    if (response.length == 2) {
        return [NSData data];
    } else {
        NSRange range = {0, response.length - 2};
        return [response subdataWithRange:range];
    }
}

- (UInt16)statusCodeFromKeyResponse:(NSData *)response {
    YKFParameterAssertReturnValue(response, YKFAPDUErrorCodeWrongLength);
    YKFAssertReturnValue(response.length >= 2, @"Key response data is too short.", YKFAPDUErrorCodeWrongLength);
    
    return [response ykf_getBigEndianIntegerInRange:NSMakeRange([response length] - 2, 2)];
}

@end
