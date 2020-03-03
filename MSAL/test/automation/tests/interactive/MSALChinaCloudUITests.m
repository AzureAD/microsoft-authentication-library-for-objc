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

#import "MSALBaseAADUITest.h"
#import "XCUIElement+CrossPlat.h"
#import "MSALNationalCloudUITest.h"

@interface MSALChinaCloudUITests : MSALNationalCloudUITest

@end

@implementation MSALChinaCloudUITests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMultipleOrgs;
    appConfigurationRequest.testAppEnvironment = MSIDTestAppEnvironmentChinaCloud;
    
    [self loadTestApp:appConfigurationRequest];
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = MSIDTestAccountEnvironmentTypeChinaCloud;
    
    [self loadTestAccount:accountConfigurationRequest];
    
    self.nationalCloudEnvironment = [NSString stringWithFormat:@"%@-instance_aware", MSIDTestAccountEnvironmentTypeChinaCloud];
}

#pragma mark - Interactive tests

- (void)testInstanceAwareWithNationalCloud_withChinaCloud
{
    [self runInstanceAwareTestWithNationalCloud];
}

- (void)testInstanceAwareWithNationalCloud_withOrganizationsAuthority_withChinaCloud
{
    [self runInstanceAwareTestWithNationalCloud_withOrganizationsAuthority];
}

- (void)testInstanceAwareWithNationalCloud_withOrganizationsAuthority_withLoginHintPresent_andEQP_withChinaCloud
{
    [self runInstanceAwareTestWithNationalCloud_withOrganizationsAuthority_withLoginHintPresent_andEQP];
}

- (void)testNonInstanceAwareWithNationalCloud_withSystemWebView_withChinaCloud
{
    [self runNonInstanceAwareTestWithNationalCloud_withSystemWebView];
}

@end
