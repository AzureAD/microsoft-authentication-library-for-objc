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

import UIKit

class SampleMainViewController: UIViewController {

    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    var events: [Date: [SampleCalendarEvent]]!
    var keys: [Date]!
    
    fileprivate static let s_dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
    
    fileprivate static let s_timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.dataSource = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        loadPhoto()
        loadEvents()
        
        do {
            let account = try SampleMSALAuthentication.shared.currentAccount()
            nameLabel.text = "Welcome, \(account.username!)"
        } catch let error {
            print("Loading current account name error: \(error)")
        }
        
        
    }
    
    @IBAction func signOut(_ sender: Any) {
        do {
            try SampleMSALAuthentication.shared.signOut()
        } catch let error {
            print("Sign out error: \(error)")
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.showLoginVC()
    }

}

// MARK: Loading/setting photo and events
fileprivate extension SampleMainViewController {
    
    func loadPhoto() {
        let photoUtil = SamplePhotoUtil.shared
        setUserPhoto(withPhoto: photoUtil.cachedPhoto())
        
        photoUtil.checkUpdatePhoto(parentController: self, withCompletion: {
            (image, error) in
            
            if let error = error {
                print("checkUpdatePhoto error: \(error)")
                return
            }
            
            if let image = image {
                self.setUserPhoto(withPhoto: image)
            }
        })
    }
    
    func setUserPhoto(withPhoto photo: UIImage) {
        profileImageView.image = photo
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.borderWidth = 4.0
        profileImageView.layer.borderColor = UIColor.white.cgColor
        profileImageView.clipsToBounds = true
    }
    
    
    func loadEvents() {
        let calendarUtil = SampleCalendarUtil.shared
        events = calendarUtil.cachedEvents
        keys = events.keys.sorted()
        
        tableView.reloadData()
        
        calendarUtil.getEvents(parentController: self, withCompletion: {
            (events: [Date : [SampleCalendarEvent]]?, error: Error?) in
            
            if let error = error {
                print("getEvents error: \(error)")
            }
            
            if let events = events {
                self.keys = events.keys.sorted()
                self.events = events
                self.tableView.reloadData()
            }
        })
    }
}

// MARK: UITableViewDataSource
extension SampleMainViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return keys.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let events = events[keys[section]] {
            return events.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SampleMainViewController.s_dayFormatter.string(from: keys[section])
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "eventCell")
        
        if cell == nil {
            cell = UITableViewCell.init(style: .subtitle, reuseIdentifier: "eventCell")
        }
        
        let date = keys[indexPath.section]
        let event = (events[date]!)[indexPath.row]
        
        cell!.textLabel?.text = event.subject
        cell!.detailTextLabel?.text = SampleMainViewController.s_timeFormatter.string(from: event.startDate)
        
        return cell!
    }

}
