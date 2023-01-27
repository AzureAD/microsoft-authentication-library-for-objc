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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthTestLogger : NSObject {
    @objc dynamic var containsPII = false
    @objc dynamic var callbackInvokedCount = 0
    @objc dynamic var messages = NSMutableArray()
    var expectation = XCTestExpectation()
    
    override init () {
        super.init()
        MSALGlobalConfig.loggerConfig.setLogCallback { [weak self] level, message, containsPII in
            self?.messages.add(message as Any)
            self?.containsPII = containsPII
            self?.callbackInvokedCount += 1
            // Making sure expectation has been set in the test case
            if self?.expectation.description != "" {
                self?.expectation.fulfill()
            }
        }
    }
    
    func reset() {
        expectation = XCTestExpectation(description: "")
        containsPII = false
        callbackInvokedCount = 0
        messages.removeAllObjects()
        MSALGlobalConfig.loggerConfig.logLevel = .last
    }
}

final class MSALNativeLoggingTests: XCTestCase {
    
    static let staticLogger = MSALNativeAuthTestLogger()
    // Used for clarity of code. The static object is needed because MSALGlobalConfig.loggerConfig.setLogCallback
    // must be set only once per execution of test
    var logger : MSALNativeAuthTestLogger {
        MSALNativeLoggingTests.staticLogger
    }
    let context = MSIDBasicContext()
    var correlationId = UUID()
    let messageRegexFormat = "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2} - %@\\] %@"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        logger.reset()
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskAllPII
        context.correlationId = UUID()
        correlationId = UUID()
    }
    
    // MARK: Log With Context
    
    func testLogWithContext() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", "String")
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test String"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }

    
    func testLogWithContext_andMasked() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(not-null\\)"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }
    
    func testLogWithContext_maskedAndNull() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(null\\)"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }
    
    // MARK: Log PII With Context
    
    func testLogPIIWithContext_andMaskAll() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskAllPII
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(not\\-null\\)"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertFalse(logger.containsPII)
    }
    
    func testLogPIIWithContext_andMaskEUII() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskEUIIOnly
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test String"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertTrue(logger.containsPII)
    }
    
    func testLogPIIWithContext_nilString() throws {
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(null\\)"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertFalse(logger.containsPII)
    }
    
    func testLogPIIWithContext_nilStringNotMasked() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskEUIIOnly
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, context: context, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test \\(null\\)"
            let correlationId = context.correlationId?.uuidString ?? "Wrong Correlation Id"
            if string.range(of: String(format:messageRegexFormat, correlationId, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertTrue(logger.containsPII)
    }
    
    // MARK: Log With Correlation Id
    
    func testLogWithCorrelationId() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", "String")
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test String"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }
    
    func testLogWithCorrelationId_andMasked() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(not\\-null\\)"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }
    
    func testLogWithCorrelationId_maskedAndNull() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.log(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(null\\)"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
    }
    
    // MARK: Log PII With CorrelationId
    
    func testLogPIIWithCorrelationId_andMaskAll() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskAllPII
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(not\\-null\\)"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertFalse(logger.containsPII)
    }
    
    func testLogPIIWithCorrelationId_andMaskEUII() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskEUIIOnly
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII("String"))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test String"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertTrue(logger.containsPII)
    }
    
    func testLogPIIWithCorrelationId_nilString() throws {
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test Masked\\(null\\)"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertFalse(logger.containsPII)
    }
    
    func testLogPIIWithCorrelationId_nilStringNotMasked() throws {
        MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskEUIIOnly
        
        logger.expectation = XCTestExpectation(description: "Callback Invoked")
        MSALLogger.logPII(level: .error, correlationId: correlationId, filename: #file, lineNumber: #line, function: #function, format: "Test %@", MSALLogMask.maskPII(nil))
        XCTWaiter().wait(for: [logger.expectation], timeout: 1)
        
        XCTAssertNotNil(logger.messages.object(at: 0));
        if let string = logger.messages.object(at: 0) as? String {
            let correctString = "Test \\(null\\)"
            if string.range(of: String(format:messageRegexFormat, correlationId.uuidString, correctString), options: .regularExpression, range: nil, locale: nil) == nil {
                XCTFail("Message doesn't contain proper data or has incorrect format")
            }
        } else {
            XCTFail("Message is not string")
        }
        XCTAssertTrue(logger.containsPII)
    }
}
