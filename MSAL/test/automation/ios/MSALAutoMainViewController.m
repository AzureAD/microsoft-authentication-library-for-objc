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

#import "MSAL.h"
#import "MSALLogger+Internal.h"

#import "MSALAutoMainViewController.h"
#import "MSALAutoResultViewController.h"
#import "MSALAutoRequestViewController.h"

#import "MSAL.h"

@interface MSALAutoMainViewController ()
{
    NSMutableString *_resultLogs;
}

@end

@implementation MSALAutoMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [MSALLogger sharedLogger].PiiLoggingEnabled = YES;
    [[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII) {
        (void)level;
        if (!containsPII)
        {
            return;
        }
        
        if (_resultLogs)
        {
            [_resultLogs appendString:message];
        }
    }];
    
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelVerbose];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    (void)sender;
    
    if ([segue.identifier isEqualToString:@"showRequest"])
    {
        MSALAutoRequestViewController *requestVC = segue.destinationViewController;
        requestVC.completionBlock = sender[@"completionBlock"];
    }
    
    
    if ([segue.identifier isEqualToString:@"showResult"])
    {
        MSALAutoResultViewController *resultVC = segue.destinationViewController;
        resultVC.resultInfoString = sender[@"resultInfo"];
        resultVC.resultLogsString = sender[@"resultLogs"];
    }
}


- (IBAction)acquireToken:(id)sender {
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        _resultLogs = [NSMutableString new];
        
        if(parameters[@"error"])
        {
            [self dismissViewControllerAnimated:NO completion:^{
                [self displayResultJson:parameters[@"error"]
                                   logs:_resultLogs];
            }];
            return;
        }
        
        NSError *error = nil;
        
        MSALPublicClientApplication *clientApplication =
        [[MSALPublicClientApplication alloc] initWithClientId:parameters[@"client_id"]
                                                    authority:parameters[@"authority"]
                                                        error:&error];
        
        if (error)
        {
            [self displayError:error];
            return;
        }
      
        NSArray *scopes = (NSArray *)parameters[@"scopes"];
        
        [clientApplication acquireTokenForScopes:scopes
                                 completionBlock:^(MSALResult *result, NSError *error)
        {
            if (error)
            {
                [self dismissViewControllerAnimated:NO
                                         completion:^{
                                             [self displayError:error];
                                         }];
                return;
            }
            
            [self dismissViewControllerAnimated:NO
                                     completion:^{
                                         [self displayResultJson:[self createJsonFromResult:result]
                                                            logs:_resultLogs];
                                     }];
        }];
    };
    
    [self performSegueWithIdentifier:@"showRequest" sender:@{@"completionBlock" : completionBlock}];
    
}

- (void)displayError:(NSError *)error
{
    NSString *errorString = [NSString stringWithFormat:@"Error Domain=%@ Code=%ld Description=%@", error.domain, (long)error.code, error.localizedDescription];
    
    [self displayResultJson:[NSString stringWithFormat:@"{\"error\" : \"%@\"}", errorString]
                       logs:_resultLogs];
}

- (void)displayResultJson:(NSString *)resultJson logs:(NSString *)resultLogs
{
    [self performSegueWithIdentifier:@"showResult" sender:@{@"resultInfo":resultJson,
                                                            @"resultLogs":resultLogs}];
}

- (NSString *)createJsonStringFromDictionary:(NSDictionary *)dictionary
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (!jsonData)
    {
        return [NSString stringWithFormat:@"{\"error\" : \"%@\"}", error.description];
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)createJsonFromResult:(MSALResult *)result
{
    // TODO: settle on what to show for test to succeed
    return [self createJsonStringFromDictionary:
            @{@"access_token":result.accessToken,
              @"scopes":result.scopes,
              @"tenantId":(result.tenantId) ? result.tenantId : @"",
              @"expires_on":[NSString stringWithFormat:@"%f", result.expiresOn.timeIntervalSince1970]}];
}

@end
