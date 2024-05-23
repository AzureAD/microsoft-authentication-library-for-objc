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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


import SwiftUI

@main
struct MSAL_Test_App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
                    
                    MSALGlobalConfig.loggerConfig.setLogCallback { (logLevel, message, containsPII) in
                        
                        // If PiiLoggingEnabled is set YES, this block will potentially contain sensitive information (Personally Identifiable Information), but not all messages will contain it.
                        // containsPII == YES indicates if a particular message contains PII.
                        // You might want to capture PII only in debug builds, or only if you take necessary actions to handle PII properly according to legal requirements of the region
                        if let displayableMessage = message {
                            if (!containsPII) {
                                #if DEBUG
                                // NB! This sample uses print just for testing purposes
                                // You should only ever log to NSLog in debug mode to prevent leaking potentially sensitive information
                                print(displayableMessage)
                                #endif
                            }
                        }
                    }
                }
            
                .onOpenURL { (url) in
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
    }
}
