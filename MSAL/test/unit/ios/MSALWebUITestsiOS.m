 //------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALTestLogger.h"
#import "MSALWebUI.h"
#import "UIApplication+MSALExtensions.h"
#import "MSALFakeViewController.h"
#import "SFSafariViewController+TestOverrides.h"

@interface MSALWebUITestsiOS : MSALTestCase

@end

@implementation MSALWebUITestsiOS

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testStartNoViewController
{
    [MSALFakeViewController returnNilForCurrentController];
    NSURL *testURL = [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"];
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorNoViewController);
         
         dispatch_semaphore_signal(dsem);
     }];
    wait_and_run_main_thread(dsem);
}

- (void)testAlreadyRunningSession
{
    __block MSALFakeViewController *fakeSvc = nil;
    [SFSafariViewController setValidationBlock:^(MSALFakeViewController *controller, NSURL *url, BOOL entersReaderIfAvailable)
     {
         fakeSvc = controller;
         XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"]);
         XCTAssertFalse(entersReaderIfAvailable);
     }];
    
    NSURL *testURL = [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"];
    dispatch_semaphore_t dsem1 = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
     {
         XCTAssertNotNil(response);
         XCTAssertNil(error);
         
         XCTAssertEqualObjects(response, [NSURL URLWithString:@"https://msal/?code=iamtotallyalegitresponsecode"]);
         dispatch_semaphore_signal(dsem1);
     }];
    
    dispatch_semaphore_t dsem2 = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorInteractiveSessionAlreadyRunning);
         dispatch_semaphore_signal(dsem2);
     }];
    
    wait_and_run_main_thread(dsem2);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MSALWebUI handleResponse:[NSURL URLWithString:@"https://msal/?code=iamtotallyalegitresponsecode"]];
    });
    
    wait_and_run_main_thread(dsem1);
    
    MSALFakeViewController *fakeController = [MSALFakeViewController currentController];
    XCTAssertTrue(fakeController.wasPresented);
    XCTAssertTrue(fakeSvc.wasDismissed);
}

- (void)testCancelSession
{
    __block MSALFakeViewController *fakeSvc = nil;
    [SFSafariViewController setValidationBlock:^(MSALFakeViewController *controller, NSURL *url, BOOL entersReaderIfAvailable)
     {
         fakeSvc = controller;
         XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"]);
         XCTAssertFalse(entersReaderIfAvailable);
     }];
    
    NSURL *testURL = [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"];
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorSessionCanceled);
         
         dispatch_semaphore_signal(dsem);
     }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MSALWebUI cancelCurrentWebAuthSession];
    });
    
    wait_and_run_main_thread(dsem);
    
    MSALFakeViewController *fakeController = [MSALFakeViewController currentController];
    XCTAssertTrue(fakeController.wasPresented);
    XCTAssertTrue(fakeSvc.wasDismissed);
}

- (void)testUserCancelSession
{
    __block MSALFakeViewController *fakeSvc = nil;
    [SFSafariViewController setValidationBlock:^(MSALFakeViewController *controller, NSURL *url, BOOL entersReaderIfAvailable)
     {
         fakeSvc = controller;
         XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"]);
         XCTAssertFalse(entersReaderIfAvailable);
     }];
    
    NSURL *testURL = [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"];
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorUserCanceled);
         dispatch_semaphore_signal(dsem);
     }];
    
    // A delegate should be set on the Safari View Controller
    dispatch_async(dispatch_get_main_queue(), ^{
        id<SFSafariViewControllerDelegate> delegate = fakeSvc.delegate;
        XCTAssertNotNil(delegate);
        [delegate safariViewControllerDidFinish:(SFSafariViewController *)fakeSvc];
    });
    
    wait_and_run_main_thread(dsem);
    
    MSALFakeViewController *fakeController = [MSALFakeViewController currentController];
    XCTAssertTrue(fakeController.wasPresented);
    XCTAssertTrue(fakeSvc.wasDismissed);
}

- (void)testNilResponse
{
    XCTAssertFalse([MSALWebUI handleResponse:nil]);
    MSALTestLogger *logger = [MSALTestLogger sharedLogger];
    XCTAssertTrue([logger.lastMessage containsString:@"nil"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelError);
}

- (void)testNoCurrentSession
{
    XCTAssertFalse([MSALWebUI handleResponse:[NSURL URLWithString:@"https://iamafakeresponse.com"]]);
    MSALTestLogger *logger = [MSALTestLogger sharedLogger];
    XCTAssertTrue([logger.lastMessage containsString:@"session"]);
    XCTAssertEqual(logger.lastLevel, MSALLogLevelError);
}

- (void)testStartAndHandleCodeResponse
{
    __block MSALFakeViewController *fakeSvc = nil;
    [SFSafariViewController setValidationBlock:^(MSALFakeViewController *controller, NSURL *url, BOOL entersReaderIfAvailable)
    {
        fakeSvc = controller;
         XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"]);
        XCTAssertFalse(entersReaderIfAvailable);
    }];
    
    NSURL *testURL = [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"];
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    [MSALWebUI startWebUIWithURL:testURL
                         context:nil
                 completionBlock:^(NSURL *response, NSError *error)
    {
        XCTAssertNotNil(response);
        XCTAssertNil(error);
        
        XCTAssertEqualObjects(response, [NSURL URLWithString:@"https://msal/?code=iamtotallyalegitresponsecode"]);
        dispatch_semaphore_signal(dsem);
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MSALWebUI handleResponse:[NSURL URLWithString:@"https://msal/?code=iamtotallyalegitresponsecode"]];
    });
    
    wait_and_run_main_thread(dsem);
    
    MSALFakeViewController *fakeController = [MSALFakeViewController currentController];
    XCTAssertTrue(fakeController.wasPresented);
    XCTAssertTrue(fakeSvc.wasDismissed);
}

@end
