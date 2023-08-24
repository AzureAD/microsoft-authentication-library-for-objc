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

public class MSALNativeAuthErrorRequiredAttributes: NSObject, Decodable {
    public let name: String
    public let type: String
    public let required: Bool
    public let options: RequiredAttributeOptions?
    
    public init(name: String, type: String, required: Bool, options: RequiredAttributeOptions? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.options = options
    }
    
    public override var description: String {
        return "\(name)"
    }
}

public class RequiredAttributeOptions: NSObject, Decodable {
    let regex : String?
}

class MSALNativeAuthErrorBasicAttributes: NSObject, Decodable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
}

