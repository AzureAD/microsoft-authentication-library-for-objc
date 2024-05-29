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

extension NSError {
    func messageCodeAndCorrelationIdFromMSALError() -> (message: String?, code: Int?, correlationId: UUID?) {
        var errorMessage: String?
        var errorCode: Int?
        var errorCorrelationId: UUID?

        if let message = userInfo[MSALErrorDescriptionKey] as? String {
            errorMessage = message
            (errorCode, errorCorrelationId) = codeAndCorrelationIdFromMSALError()
        }

        if let innerError = userInfo[NSUnderlyingErrorKey] as? NSError,
           let message = innerError.userInfo[MSALErrorDescriptionKey] as? String {
            errorMessage = message
            (errorCode, errorCorrelationId) = innerError.codeAndCorrelationIdFromMSALError()
        }
        
        return (errorMessage, errorCode, errorCorrelationId)
    }
    
    func codeAndCorrelationIdFromMSALError() -> (code: Int?, correlationId: UUID?) {
        var errorCode: Int?
        var errorCorrelationId: UUID?
        
        if let code = userInfo[MSALInternalErrorCodeKey] as? Int {
            errorCode = code
        }
        
        if let correlationId = userInfo[MSALCorrelationIDKey] as? String {
            errorCorrelationId = UUID(uuidString: correlationId)
        }
        
        return (errorCode, errorCorrelationId)
    }
}
