//
//  SampleTokenProvider.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import Foundation
import MSAL
import MSALNativeCredManagment

/// A sample fake token provider for POC purposes.
/// Returns a hardcoded access token without calling MSAL.
class SampleTokenProvider: NSObject, MSALNativeCredentialManagementTokenProvider {

    private var isSignedIn = false

    func setSignedIn(_ signedIn: Bool) {
        isSignedIn = signedIn
    }

    func getAccessToken(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    ) {
        guard isSignedIn else {
            let error = NSError(
                domain: "SampleTokenProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user signed in. Please sign in first."]
            )
            completionBlock(nil, error)
            return
        }

        // Return a fake access token for POC
        let fakeToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.fake-poc-access-token"
        completionBlock(fakeToken, nil)
    }
}

