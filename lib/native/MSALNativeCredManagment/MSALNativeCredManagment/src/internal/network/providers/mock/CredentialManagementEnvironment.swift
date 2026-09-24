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

import Foundation

/// Internal environment switch for credential management.
///
/// Reads UserDefaults to determine whether to route API calls to the real server
/// or return mock responses. This mechanism is entirely internal and is NOT exposed
/// in any public API.
///
/// ## UserDefaults Keys
///
/// - `com.microsoft.identity.credentialmanagement.useMockAPI` (Bool):
///   When `true`, all credential management API calls will be routed to the mock client.
///   Default is `false` (real server).
///
/// - `com.microsoft.identity.credentialmanagement.mockDelaySeconds` (Double):
///   Simulated network delay in seconds when using mock API. Default is 0.5.
///
/// ## Usage (for internal testing / debug builds only)
///
/// ```swift
/// // Enable mock API (e.g., in a debug settings screen or launch argument):
/// UserDefaults.standard.set(true, forKey: "com.microsoft.identity.credentialmanagement.useMockAPI")
///
/// // Optionally configure simulated delay:
/// UserDefaults.standard.set(1.0, forKey: "com.microsoft.identity.credentialmanagement.mockDelaySeconds")
///
/// // Disable mock API (back to real server):
/// UserDefaults.standard.set(false, forKey: "com.microsoft.identity.credentialmanagement.useMockAPI")
/// ```
///
/// ## Launch Arguments
///
/// You can also pass the flag as a launch argument in Xcode:
/// `-com.microsoft.identity.credentialmanagement.useMockAPI YES`
///
internal enum CredentialManagementEnvironment
{
    /// UserDefaults key that controls mock/server routing.
    static let useMockAPIKey = "com.microsoft.identity.credentialmanagement.useMockAPI"

    /// Returns `true` when mock API mode is enabled via UserDefaults.
    static var isMockAPIEnabled: Bool
    {
        return UserDefaults.standard.bool(forKey: useMockAPIKey)
    }
}
