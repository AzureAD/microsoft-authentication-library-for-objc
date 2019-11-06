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
import UIKit

typealias CalendarCompletion = ([Date: [SampleCalendarEvent]]?, Error?) -> Void

class SampleCalendarUtil  {
    
    // Constants
    fileprivate let kLastEventsCheckKey = "last_events_check"
    fileprivate let kEventsKey = "events"
    
    // Singleton instance
    static let shared = SampleCalendarUtil()
    
    private init() {
        if let storedEvents = UserDefaults.standard.object(forKey: kEventsKey) as? [[String: Any]] {
            self.cachedEvents = processEvents(withEvents: storedEvents)
        }
        else {
            self.cachedEvents = [Date: [SampleCalendarEvent]]()
        }
    }
    
    /*
     Returns cached events (if any) for the current user
     */
    var cachedEvents: [Date: [SampleCalendarEvent]]!
    
    /*
     Clears any cached events for the current user
     */
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: kLastEventsCheckKey)
        cachedEvents.removeAll()
    }
    
    /*
     Retrieves updated calendar event information from Microsoft graph
     */
    func getEvents(parentController : UIViewController, withCompletion completion: @escaping CalendarCompletion) {
        
        if checkTimestamp() == false {
            return
        }
        
        SampleMSALAuthentication.shared.acquireTokenForCurrentAccount(parentController: parentController, forScopes: [GraphScopes.CalendarsRead.rawValue]) {
            (token: String?, error: Error?) in
            
            guard let accessToken = token, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            self.getJsonEvents(withToken: accessToken, completion: {
                (jsonEvents: [[String : Any]]?, error: Error?) in
                
                self.setLastChecked()
                let processedEvents = self.processEvents(withEvents: jsonEvents)
                
                DispatchQueue.main.async {
                    if let jsonEvents = jsonEvents {
                        self.storeEvents(withJsonArray: jsonEvents)
                        self.cachedEvents = processedEvents
                    }
                    completion(processedEvents, error)
                }
            })
        }
    }
}

// MARK: Private methods
fileprivate extension SampleCalendarUtil {
    
    func processEvents(withEvents events: [[String: Any]]?) -> [Date: [SampleCalendarEvent]] {
        
        guard let events = events else {
            return [Date: [SampleCalendarEvent]]()
        }
        
        var eventDictionary = [Date: [SampleCalendarEvent]]()
        let calendar = Calendar.current
        
        for jsonEvent in events {
            if let event = SampleCalendarEvent.event(withJson: jsonEvent) {
                if event.startDate.timeIntervalSinceNow < 0 {
                    continue
                }
                
                let day = calendar.startOfDay(for: event.startDate)
                
                if (eventDictionary[day] == nil) {
                    eventDictionary[day] = [SampleCalendarEvent]()
                }
                
                eventDictionary[day]!.append(event)
            }
        }
        
        return eventDictionary
    }
    
    func checkTimestamp() -> Bool {
        if let lastChecked = UserDefaults.standard.object(forKey: kLastEventsCheckKey) as? Date {
            // Only check for updated events every 30 minutes
            return (-lastChecked.timeIntervalSinceNow > 30 * 60)
        }
        return true
    }
    
    func setLastChecked() {
        UserDefaults.standard.set(Date(), forKey: kLastEventsCheckKey)
    }
    
    func storeEvents(withJsonArray json: [[String: Any]]) {
        UserDefaults.standard.set(json, forKey: kEventsKey)
    }
    
    func getJsonEvents(withToken token: String,
                       completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        
        let request = SampleGraphRequest(withToken: token)

        request.getJSON(path: "me/events?$select=subject,start") {
            (jsonEvents: [String : Any]?, error: Error?) in
            
            guard let jsonEvents = jsonEvents else {
                completion(nil, error)
                return
            }
            
            guard let verifiedJsonEvents = jsonEvents["value"] as? [[String: Any]] else {
                completion(nil, SampleAppError.ServerInvalidResponse)
                return
            }

            completion(verifiedJsonEvents, nil)
        }
    }
}


