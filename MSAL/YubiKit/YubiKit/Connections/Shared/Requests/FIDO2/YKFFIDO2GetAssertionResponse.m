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

#import "YKFFIDO2GetAssertionResponse.h"
#import "YKFFIDO2GetAssertionResponse+Private.h"
#import "YKFCBORDecoder.h"
#import "YKFFIDO2Type.h"
#import "YKFAssert.h"

typedef NS_ENUM(NSUInteger, YKFFIDO2GetAssertionResponseKey) {
    YKFFIDO2GetAssertionResponseKeyCredential            = 0x01,
    YKFFIDO2GetAssertionResponseKeyAuthData              = 0x02,
    YKFFIDO2GetAssertionResponseKeySignature             = 0x03,
    YKFFIDO2GetAssertionResponseKeyUser                  = 0x04,
    YKFFIDO2GetAssertionResponseKeyNumberOfCredentials   = 0x05
};

@interface YKFFIDO2GetAssertionResponse()

@property (nonatomic, readwrite) YKFFIDO2PublicKeyCredentialDescriptor *credential;
@property (nonatomic, readwrite) NSData *authData;
@property (nonatomic, readwrite) NSData *signature;
@property (nonatomic, readwrite) YKFFIDO2PublicKeyCredentialUserEntity *user;
@property (nonatomic, readwrite) NSInteger numberOfCredentials;

@property (nonatomic, readwrite) NSData *rawResponse;

@end

@implementation YKFFIDO2GetAssertionResponse

- (instancetype)initWithCBORData:(NSData *)cborData {
    self = [super init];
    if (self) {
        YKFAssertAbortInit(cborData);
        self.rawResponse = cborData;
        
        YKFCBORMap *responseMap = nil;
        
        NSInputStream *decoderInputStream = [[NSInputStream alloc] initWithData:cborData];
        [decoderInputStream open];
        responseMap = [YKFCBORDecoder decodeObjectFrom:decoderInputStream];
        [decoderInputStream close];
        
        YKFAssertAbortInit(responseMap);
        
        BOOL success = [self parseResponseMap: responseMap];
        YKFAssertAbortInit(success);
    }
    return self;
}

#pragma mark - Private

- (BOOL)parseResponseMap:(YKFCBORMap *)map {
    id convertedObject = [YKFCBORDecoder convertCBORObjectToFoundationType:map];
    if (!convertedObject || ![convertedObject isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)convertedObject;
    
    // Credential    
    NSDictionary *responseCredential = response[@(YKFFIDO2GetAssertionResponseKeyCredential)];
    if (responseCredential) {
        YKFFIDO2PublicKeyCredentialDescriptor *credentialDescriptor = [[YKFFIDO2PublicKeyCredentialDescriptor alloc] init];
        credentialDescriptor.credentialId = responseCredential[@"id"];
        
        YKFFIDO2PublicKeyCredentialType *credentialType = [[YKFFIDO2PublicKeyCredentialType alloc] init];
        credentialType.name = responseCredential[@"type"];
        credentialDescriptor.credentialType = credentialType;
        
        NSArray *responseTransports = responseCredential[@"transports"];
        NSMutableArray *transports = [[NSMutableArray alloc] initWithCapacity:responseTransports.count];
        for (NSString *responseTransport in responseTransports) {
            YKFFIDO2AuthenticatorTransport *transport = [[YKFFIDO2AuthenticatorTransport alloc] init];
            transport.name = responseTransport;
            [transports addObject: transport];
        }
        credentialDescriptor.credentialTransports = transports;
        
        self.credential = credentialDescriptor;
    }

    // Auth Data
    NSData *authData = response[@(YKFFIDO2GetAssertionResponseKeyAuthData)];    
    YKFAssertReturnValue(authData, @"authenticatorGetAssertion authData is required.", NO);
    self.authData = authData;
    
    // Signature
    NSData *signature = response[@(YKFFIDO2GetAssertionResponseKeySignature)];
    YKFAssertReturnValue(signature, @"authenticatorGetAssertion signature is required.", NO);
    self.signature = signature;
    
    // User
    NSDictionary *responseUser = response[@(YKFFIDO2GetAssertionResponseKeyUser)];
    if (responseUser) {
        YKFFIDO2PublicKeyCredentialUserEntity *user = [[YKFFIDO2PublicKeyCredentialUserEntity alloc] init];
        user.userId = responseUser[@"id"];
        user.userName = responseUser[@"name"];
        user.userDisplayName = responseUser[@"displayName"];
        user.userIcon = responseUser[@"icon"];
        self.user = user;
    }
    
    // Number Of Credentials
    NSNumber *numberOfCredentials = response[@(YKFFIDO2GetAssertionResponseKeyNumberOfCredentials)];
    if (numberOfCredentials != nil) {
        self.numberOfCredentials = numberOfCredentials.integerValue;
    }
    
    return YES;
}

@end
