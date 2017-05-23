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

import Foundation

class SampleCalendarEvent {
    
    let startDate: Date
    let subject: String
    
    private static let s_dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    private init(startDate date: Date, subject: String) {
        self.startDate = date
        self.subject = subject
    }
    
    class func event(withJson json: [String: Any]) -> SampleCalendarEvent? {
        guard let subject = json["subject"] as? String, let startDict = json["start"] as? [String: Any] else {
            return nil
        }
        
        guard let startTimeString = startDict["dateTime"] as? String else {
            return nil
        }
        
        guard let start = s_dateFormatter.date(from: startTimeString) else {
            return nil
        }
        
        return SampleCalendarEvent(startDate: start, subject: subject)
    }
}

