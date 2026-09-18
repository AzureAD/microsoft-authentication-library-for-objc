//
//  SampleRequestInterceptor.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import Foundation
import MSAL
import MSALNativeCredManagment

/// Sample request interceptor shared between MSAL and the Credential Management client.
///
/// Demonstrates how to inject custom headers into credential management requests.
class SampleRequestInterceptor: NSObject, MSALNativeAuthRequestInterceptor {

    func addAdditionalHeaderFields(
        _ requestUrl: URL?,
        completionBlock: @escaping MSALNativeAuthRequestInterceptorAddHeaderCompletionBlock
    ) {
        let headers: [String: String] = [
            "x-sample-app-version": "1.0.0"
        ]
        completionBlock(headers)
    }
}
