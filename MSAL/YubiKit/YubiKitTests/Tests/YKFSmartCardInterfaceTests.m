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
#import "FakeYKFConnectionController.h"
#import "YKFSmartCardInterface.h"
#import "YKFAPDU+Private.h"

@interface YKFSmartCardInterfaceTests: YKFTestCase

@property (nonatomic) FakeYKFConnectionController *keyConnectionController;
@property (nonatomic) YKFSmartCardInterface *smartCardInterface;


@end

@implementation YKFSmartCardInterfaceTests

- (void)setUp {
    self.keyConnectionController = [[FakeYKFConnectionController alloc] init];
    self.smartCardInterface = [[YKFSmartCardInterface alloc] initWithConnectionController:self.keyConnectionController];
}

#pragma mark - Sync commands

- (void)test_WhenRunningSmartCardCommandsAgainstTheKey_CommandsAreForwardedToTheKey {
    NSData *command = [NSData dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [NSData dataWithBytes:@[@(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"SmartCardCommands"];

    YKFAPDU *apdu = [[YKFAPDU alloc] initWithData:command];

    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            XCTAssertTrue(NO, @"Got error %@", error);
        }
        XCTAssertEqual(command, self.keyConnectionController.executionCommand.apduData);
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
}

- (void)test_WhenRunningSmartCardCommandsAgainstTheKey_ErrorCodeIsReturned {
    NSData *command = [NSData dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [NSData dataWithBytes:@[@(0x00), @(0x00), @(0x05)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"SmartCardStatusCode"];

    YKFAPDU *apdu = [[YKFAPDU alloc] initWithData:command];
    
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        XCTAssertNotNil(error, @"Failed to return error");
        XCTAssertEqual(error.code, 5);
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
}


- (void)test_WhenRunningSmartCardCommandsAgainstTheKey_ResultDataIsReturned {
    NSData *command = [NSData dataWithBytes:@[@(0x01), @(0x00)]];
    NSData *commandResponse = [NSData dataWithBytes:@[@(0x01), @(0x02), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"SmartCardStatusCode"];

    YKFAPDU *apdu = [[YKFAPDU alloc] initWithData:command];
    
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            XCTAssertTrue(NO, @"Got error %@", error);
        }
        XCTAssertEqual(data.length, 2, @"Did not get expected response length");
        NSData *expectedResult = [NSData dataWithBytes:@[@(0x01), @(0x02)]];
        XCTAssertTrue([data isEqualToData:expectedResult], @"Return data doess not match expected result");
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
}

@end
