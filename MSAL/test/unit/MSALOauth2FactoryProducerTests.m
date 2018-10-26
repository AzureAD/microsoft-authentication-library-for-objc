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

#import <XCTest/XCTest.h>
#import "MSALOauth2FactoryProducer.h"
#import "MSIDOauth2Factory.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDB2COauth2Factory.h"

@interface MSALOauth2FactoryProducerTests : XCTestCase

@end

@implementation MSALOauth2FactoryProducerTests

- (void)testOauth2FactoryForAuthority_whenNilAuthority_shouldReturnNilAndError
{
    NSError *error = nil;
    NSURL *authorityURL = nil;
    MSIDOauth2Factory *factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:authorityURL context:nil error:&error];

    XCTAssertNil(factory);
    XCTAssertNotNil(error);
}

- (void)testOauth2FactoryForAuthority_whenB2CAuthority_shouldReturnB2CFactoryNilError
{
    NSError *error = nil;
    NSURL *authorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/contoso.com/B2C_1_Signin"];
    MSIDOauth2Factory *factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:authorityURL context:nil error:&error];

    XCTAssertNotNil(factory);
    XCTAssertNil(error);
    XCTAssertTrue([factory isKindOfClass:[MSIDB2COauth2Factory class]]);
}

- (void)testOauth2FactoryForAuthority_whenAADAuthority_shouldReturnAADV2FactoryNilError
{
    NSError *error = nil;
    NSURL *authorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com/"];
    MSIDOauth2Factory *factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:authorityURL context:nil error:&error];

    XCTAssertNotNil(factory);
    XCTAssertNil(error);
    XCTAssertTrue([factory isKindOfClass:[MSIDAADV2Oauth2Factory class]]);
}

- (void)testOauth2FactoryForAuthority_whenADFSAuthority_shouldReturnAADV2FactoryNilError
{
    NSError *error = nil;
    NSURL *authorityURL = [NSURL URLWithString:@"https://contoso.com/adfs"];
    MSIDOauth2Factory *factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:authorityURL context:nil error:&error];

    XCTAssertNotNil(factory);
    XCTAssertNil(error);
    XCTAssertTrue([factory isKindOfClass:[MSIDAADV2Oauth2Factory class]]);
}

@end
