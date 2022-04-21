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

#import <XCTest/XCTest.h>

#import "YKFTestCase.h"
#import "YKFU2FSession.h"
#import "YKFU2FSession+Private.h"
#import "FakeYKFConnectionController.h"

#import "YKFAPDUError.h"
#import "YKFU2FError.h"

@interface YKFU2FServiceTests: YKFTestCase

@property (nonatomic) FakeYKFConnectionController *keyConnectionController;
@property (nonatomic) YKFU2FSession *session;

// Predefined U2F params
@property (nonatomic) NSString *challenge;
@property (nonatomic) NSString *keyHandle;
@property (nonatomic) NSString *appId;

@end

@implementation YKFU2FServiceTests

- (void)setUp {
    [super setUp];
    self.challenge = @"J3tMC4hiRP9PDQ1M4IsOp8A-_oh6hge0c38CqwiqYmo";
    self.keyHandle  = @"UiC-Kth0iN3JmoSHFeHPu5M8GUvbhC-Gv8n0q0OBt42F3S1qTZBX81UudCuT29utRQZlTP5QpO_OncQFn5Mjaw";
    self.appId = @"https://demo.yubico.com";
    self.keyConnectionController = [[FakeYKFConnectionController alloc] init];
}

- (void)test_WhenExecutingRegisterRequest_RequestIsForwarededToTheKey {
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *commandResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, commandResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session; // save session to keep it from being dealloced by ARC
        [self.session registerWithChallenge:self.challenge appId:self.appId completion:^(YKFU2FRegisterResponse * _Nullable response, NSError * _Nullable error) {
            XCTAssertNil(error, @"Unexpected error: %@", error);
            XCTAssertNotNil(response);
            [expectation fulfill];
        }];
    }];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

- (void)test_WhenExecutingSignRequest_RequestIsForwarededToTheKey {
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *commandResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, commandResponse];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session;
        
        [self.session signWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId completion:^(YKFU2FSignResponse * _Nullable response, NSError * _Nullable error) {
            XCTAssertNil(error, @"Unexpected error: %@", error);
            XCTAssertNotNil(response);
            [expectation fulfill];
        }];
    }];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

#pragma mark - Generic Error Tests

- (void)test_WhenExecutingRegisterRequestWithStatusErrorResponse_ErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [NSData dataWithBytes:@[@(0x00), @(0x6A), @(0x88)]];
    NSUInteger expectedErrorCode = 0x6A88;
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];

    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session;
        [self.session registerWithChallenge:self.challenge appId:self.appId completion:^(YKFU2FRegisterResponse * _Nullable response, NSError * _Nullable error) {
            XCTAssertNotNil(error, @"Unexpected error: %@", error);
            XCTAssertEqual(error.code, expectedErrorCode);
            XCTAssertNil(response);
            [expectation fulfill];
        }];
    }];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

- (void)test_WhenExecutingSignRequestWithStatusErrorResponse_ErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [NSData dataWithBytes:@[@(0x00), @(0x69), @(0x84)]];
    NSUInteger expectedErrorCode = 0x6984;
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];

    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session;
        [self.session signWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId completion:^(YKFU2FSignResponse * _Nullable response, NSError * _Nullable error) {
            XCTAssertNotNil(error, @"Unexpected error: %@", error);
            XCTAssertEqual(error.code, expectedErrorCode);
            XCTAssertNil(response);
            [expectation fulfill];
        }];
    }];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}


- (void)test_WhenExecutingSignRequestWithKnownStatusErrorResponse_ErrorIsReceivedBack {
    NSArray *listOfErrorStatusCodes = @[
        @[@(0x00), @(0x69), @(0x84), @(YKFAPDUErrorCodeDataInvalid)],
        @[@(0x00), @(0x67), @(0x00), @(YKFAPDUErrorCodeWrongLength)],
        @[@(0x00), @(0x6E), @(0x00), @(YKFAPDUErrorCodeCLANotSupported)],
        @[@(0x00), @(0x6F), @(0x00), @(YKFAPDUErrorCodeCommandAborted)]
    ];
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    expectation.expectedFulfillmentCount = 3;
    
    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session;
        
        for (NSArray *statusCode in listOfErrorStatusCodes) {
            NSData *errorResponse = [NSData dataWithBytes:@[statusCode[0], statusCode[1], statusCode[2]]];
            int expectedErrorCode = [statusCode[3] intValue];
            self.keyConnectionController.commandExecutionResponseDataSequence = @[errorResponse];
            
            [self.session signWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId completion:^(YKFU2FSignResponse * _Nullable response, NSError * _Nullable error) {
                XCTAssertNotNil(error, @"Unexpected error: %@", error);
                XCTAssertEqual(error.code, expectedErrorCode);
                XCTAssertNil(response);
                [expectation fulfill];
            }];
        }
    }];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

- (void)test_WhenExecutingU2FRequestWithU2FDisabled_DisabledApplicationErrorIsReceivedBack {
    NSArray *listOfErrorStatusCodes = @[
        @[@(0x00), @(0x6D), @(0x00), @(YKFSessionErrorMissingApplicationCode)], // Ins Not Supported
        @[@(0x00), @(0x6A), @(0x82), @(YKFSessionErrorMissingApplicationCode)]  // Missing file
    ];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    expectation.expectedFulfillmentCount = 2;
    
    for (NSArray *statusCode in listOfErrorStatusCodes) {
        NSData *errorResponse = [NSData dataWithBytes:@[statusCode[0], statusCode[1], statusCode[2]]];
        int expectedErrorCode = [statusCode[3] intValue];
        self.keyConnectionController.commandExecutionResponseDataSequence = @[errorResponse];
        [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
            XCTAssertNotNil(error, @"Unexpected error: %@", error);
            XCTAssertEqual(error.code, expectedErrorCode);
            XCTAssertNil(session);
            [expectation fulfill];
        }];
    }
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

#pragma mark - Mapped Error Tests

- (void)test_WhenExecutingSignRequestWithoutRegistration_MappedErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [NSData dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [NSData dataWithBytes:@[@(0x00), @(0x6A), @(0x80)]]; // Wrong data code
    NSUInteger expectedErrorCode = YKFU2FErrorCodeU2FSigningUnavailable;
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];

    [YKFU2FSession sessionWithConnectionController:self.keyConnectionController completion:^(YKFU2FSession * _Nullable session, NSError * _Nullable error) {
        self.session = session;
        [self.session signWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId completion:^(YKFU2FSignResponse * _Nullable response, NSError * _Nullable error) {
            XCTAssertNotNil(error, @"Unexpected error: %@", error);
            XCTAssertEqual(error.code, expectedErrorCode);
            XCTAssertNil(response);
            [expectation fulfill];
        }];
    }];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
}

#pragma mark - Key State Tests

- (void)disabled_test_WhenExecutingRegisterRequestWithTouchRequired_KeyStateIsUpdatingToTouchKey {
    /*
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x69), @(0x85)]]; // Condition not satisified - touch the key
    NSData *successResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse, successResponse];
    
    YKFU2FRegisterRequest *registerRequest = [[YKFU2FRegisterRequest alloc] initWithChallenge:self.challenge appId:self.appId];
    YKFU2FSessionRegisterCompletionBlock completionBlock = ^(YKFU2FRegisterResponse *response, NSError *error) {};
    [self.u2fService registerWithChallenge:registerRequest completion:completionBlock];
    
    [self waitForTimeInterval:0.3]; // give time to update the property
    
    YKFU2FSessionKeyState keyState = self.u2fService.keyState;
    
    XCTAssertTrue(keyState == YKFU2FSessionKeyStateTouchKey, @"The keys state did not update to touch key.");
     */
}

- (void)disabled_test_WhenExecutingSignRequestWithTouchRequired_KeyStateIsUpdatingToTouchKey {
    /*
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x69), @(0x85)]]; // Condition not satisified - touch the key
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    YKFU2FSignRequest *signRequest = [[YKFU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFU2FSessionSignCompletionBlock completionBlock = ^(YKFU2FSignResponse *response, NSError *error) {
        [expectation fulfill];
    };
    [self.u2fService signWithChallenge:signRequest completion:completionBlock];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    YKFU2FSessionKeyState keyState = self.u2fService.keyState;
    
    XCTAssertTrue(keyState == YKFU2FSessionKeyStateTouchKey, @"The keys state did not update to touch key.");
     */
}

- (void)disabled_test_WhenNoRequestWasSentToTheKey_KeyStateIsIdle {
    /*
    YKFU2FSessionKeyState keyState = self.u2fService.keyState;
    XCTAssertTrue(keyState == YYKFU2FSessionKeyStateIdle, @"The keys state idle when the service does not execute a request.");
     */
}

@end
