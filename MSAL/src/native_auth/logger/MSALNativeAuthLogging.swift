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

@_implementationOnly import MSAL_Private

protocol MSALLogging {
    static func log(
        level: MSIDLogLevel,
        context: MSIDRequestContext?,
        filename: String,
        lineNumber: Int,
        function: String,
        format: String,
        _ args: CVarArg...)
    static func logPII(
        level: MSIDLogLevel,
        context: MSIDRequestContext?,
        filename: String,
        lineNumber: Int,
        function: String,
        format: String,
        _ args: CVarArg...)
    static func log(
        level: MSIDLogLevel,
        correlationId: UUID?,
        filename: String,
        lineNumber: Int,
        function: String,
        format: String,
        _ args: CVarArg...)
    static func logPII(
        level: MSIDLogLevel,
        correlationId: UUID?,
        filename: String,
        lineNumber: Int,
        function: String,
        format: String,
        _ args: CVarArg...)
}

extension MSALLogger: MSALLogging {
    private static func logCommon(level: MSIDLogLevel,
                                  context: MSIDRequestContext? = nil,
                                  correlationId: UUID? = nil,
                                  containsPII: Bool,
                                  filename: String = #fileID,
                                  lineNumber: Int = #line,
                                  function: String = #function,
                                  format: String,
                                  _ args: CVaListPointer) {
        MSIDLogger.shared().log(with: level,
                                context: context,
                                correlationId: correlationId,
                                containsPII: containsPII,
                                filename: filename,
                                lineNumber: UInt(lineNumber),
                                function: function,
                                format: format,
                                formatArgs: args)
    }

    static func log(level: MSIDLogLevel,
                    context: MSIDRequestContext?,
                    filename: String = #fileID,
                    lineNumber: Int = #line,
                    function: String = #function,
                    format: String,
                    _ args: CVarArg...) {
        logCommon(level: level,
                  context: context,
                  containsPII: false,
                  filename: filename,
                  lineNumber: lineNumber,
                  function: function,
                  format: format,
                  getVaList(args))
    }

    static func logPII(level: MSIDLogLevel,
                       context: MSIDRequestContext?,
                       filename: String = #fileID,
                       lineNumber: Int = #line,
                       function: String = #function,
                       format: String,
                       _ args: CVarArg...) {
        logCommon(level: level,
                  context: context,
                  containsPII: true,
                  filename: filename,
                  lineNumber: lineNumber,
                  function: function,
                  format: format,
                  getVaList(args))
    }

    static func log(level: MSIDLogLevel,
                    correlationId: UUID?,
                    filename: String = #fileID,
                    lineNumber: Int = #line,
                    function: String = #function,
                    format: String,
                    _ args: CVarArg...) {
        logCommon(level: level,
                  correlationId: correlationId,
                  containsPII: false,
                  filename: filename,
                  lineNumber: lineNumber,
                  function: function,
                  format: format,
                  getVaList(args))
    }

    static func logPII(level: MSIDLogLevel,
                       correlationId: UUID?,
                       filename: String = #fileID,
                       lineNumber: Int = #line,
                       function: String = #function,
                       format: String,
                       _ args: CVarArg...) {
        logCommon(level: level,
                  correlationId: correlationId,
                  containsPII: true,
                  filename: filename,
                  lineNumber: lineNumber,
                  function: function,
                  format: format,
                  getVaList(args))
    }
}
