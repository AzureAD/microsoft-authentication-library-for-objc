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
#import "MSALWebUI.h"
#import "MSALTestSwizzle.h"
#import "UIApplication+MSALExtensions.h"

#import <SafariServices/SafariServices.h>

@interface MSALFakeViewController : NSObject

@property BOOL wasPresented;

@end

@implementation MSALFakeViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:(void (^ __nullable)(void))completion
{
    if (!viewControllerToPresent)
    {
        @throw @"no view controller!";
    }
    
    (void)flag;
    (void)completion;
    
    self.wasPresented = YES;
}

@end

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
    while (dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW))
    {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
    }
}

typedef id(*ReturnIdIdBoolPtr)(id, SEL, id, BOOL);

- (void)testStartAndHandleCodeResponse
{
    __block MSALFakeViewController *fakeController = [MSALFakeViewController new];
    [MSALTestSwizzle classMethod:@selector(msalCurrentViewController)
                           class:[UIApplication class]
                           block:(id)^id(id obj)
    {
#pragma unused (obj)
        return fakeController;
    }];
    
    __block MSALTestSwizzle *swizzle =
    [MSALTestSwizzle instanceMethod:@selector(initWithURL: entersReaderIfAvailable:)
                              class:[SFSafariViewController class]
                              block:(id)^id(id obj, id arg1, BOOL arg2)
     {
         XCTAssertEqualObjects(arg1, [NSURL URLWithString:@"https://iamafakeurl.contoso.com/do/authy/things"]);
         
         return ((ReturnIdIdBoolPtr)[swizzle originalIMP])(obj, [swizzle sel], arg1, arg2);
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
    
    while (dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW))
    {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
    }
    
    XCTAssertTrue(fakeController.wasPresented);
}

@end
