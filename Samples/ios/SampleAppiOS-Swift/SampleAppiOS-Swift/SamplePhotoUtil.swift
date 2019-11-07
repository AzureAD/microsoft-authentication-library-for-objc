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

typealias PhotoCompletion = (UIImage?, Error?) -> Void

class SamplePhotoUtil {

    // Constants
    fileprivate let kLastPhotoCheckKey = "last_photo_check"
    fileprivate let kSecondsPerDay: Double = 3600 * 24
    
    // Variables
    fileprivate var currentUserPhoto: UIImage?
    
    // Singleton instance
    static let shared = SamplePhotoUtil()
    
    // Returns the current photo in the cache for the user, or the placeholder image if none is in the cache
    func cachedPhoto() -> UIImage {
        if let currentUserPhoto = currentUserPhoto {
            return currentUserPhoto
        }
        
        if let cachedImagePath = cachedImagePath(), let cachedImage = UIImage(contentsOfFile: cachedImagePath) {
            currentUserPhoto = cachedImage
        }
        else {
            currentUserPhoto = UIImage(named: "no_photo")
        }
        
        return currentUserPhoto!
    }
    
    // Checks with the graph for an updated photo, if enough time has passed since the last check
    func checkUpdatePhoto(parentController : UIViewController, withCompletion completion: @escaping PhotoCompletion) {
        if checkTimestamp() == false {
            return
        }
        
        getUserPhotoImpl(parentController: parentController, with: {
            (image, error) in
            DispatchQueue.main.async {
                completion(image, error)
            }
        })
    }
    
    // Clears out any cached data for the current user
    func clearPhotoCache() {
        UserDefaults.standard.removeObject(forKey: kLastPhotoCheckKey)
        currentUserPhoto = nil
        
        if let _ = SampleMSALAuthentication.shared.currentAccountIdentifier {
            
            guard let imagePath = cachedImagePath() else {
                print("User is not signed in. There is nothing to delete")
                return
            }
            
            do {
                try FileManager.default.removeItem(at: URL(string: imagePath)!)
            }
            catch let error {
                print("\(error)")
            }
        }
    }
}


// MARK: Caching
fileprivate extension SamplePhotoUtil {
    
    func cachedImageDirectory() -> String {
        let directories = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return "\(directories[0])/com.microsoft.MSALSampleApp/userphoto"
    }
    
    func cachedImagePath() -> String? {
        if let currentUserIdentifier = SampleMSALAuthentication.shared.currentAccountIdentifier {
            return cachedImageDirectory() + "/" + currentUserIdentifier
        }
        return nil
    }
    
    func setLastChecked() {
        UserDefaults.standard.set(Date(), forKey: kLastPhotoCheckKey)
    }
    
    func cache(photo data: Data) throws {
        let imageDirectory = cachedImageDirectory()
        
        do {
            if (FileManager.default.fileExists(atPath: imageDirectory) == false) {
                try FileManager.default.createDirectory(atPath: imageDirectory, withIntermediateDirectories: true, attributes: convertToOptionalFileAttributeKeyDictionary([:]))
            }
            
            guard let imagePath = cachedImagePath() else {
                throw SampleAppError.NoUserSignedIn
            }
            
            try data.write(to: URL(fileURLWithPath: imagePath))
        } catch let error {
            throw SampleAppError.ImageCacheError(error)
        }
    }
    
    func checkTimestamp() -> Bool {
        guard let cachedImagePath = cachedImagePath() else {
            return true
        }
        
        guard let lastChecked = UserDefaults.standard.object(forKey: kLastPhotoCheckKey) as? Date else {
            return true
        }
        
        let cachedFileExists = FileManager.default.fileExists(atPath: cachedImagePath)
        if (cachedFileExists) {
            return (-lastChecked.timeIntervalSinceNow > kSecondsPerDay * 7)
        }
        else {
            return (-lastChecked.timeIntervalSinceNow > kSecondsPerDay)
        }
    }
}

// MARK: Request
fileprivate extension SamplePhotoUtil {
    
    func getUserPhotoImpl(parentController : UIViewController, with completion: @escaping PhotoCompletion) {
        // When acquiring a token for a specific purpose you should limit the scopes
        // you ask for to just the ones needed for that operation. A user or admin might not
        // consent to all of the scopes asked for, and core application functionality should
        // not be blocked on not having consent for edge features.
        let scopesRequired = [GraphScopes.UserRead.rawValue];
        
        SampleMSALAuthentication.shared.acquireTokenForCurrentAccount(parentController: parentController, forScopes: scopesRequired) {
            (token, error) in
            
            guard let accessToken = token, error == nil else {
                completion(nil, error)
                return
            }
            
            self.getPhoto(withToken: accessToken, completion: completion)
        }
    }
    
    
    func getPhoto(withToken accessToken: String, completion: @escaping PhotoCompletion) {
        let request = SampleGraphRequest(withToken: accessToken)
        
        getPhotoData(withRequest: request) {
            (data, error) in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            self.setLastChecked()
            
            guard let data = data else {
                print("No data returned from graph for photo")
                completion(UIImage(named: "no_photo"), nil)
                return
            }
            
            guard let image = UIImage(data: data) else {
                completion(nil, SampleAppError.FailedToMakeUIImageError)
                return
            }
            
            do {
                try self.cache(photo: data)
            } catch let error {
                completion(nil, error)
                return
            }
            self.currentUserPhoto = image
            
            completion(image, nil)
        }
    }
    
    func getMetaData(withRequest request: SampleGraphRequest, completion: @escaping ([String: Any]?, Error?) -> Void) {
        request.getJSON(path: "me/photo") {
            (json: [String : Any]?, error: Error?) in
            completion(json, error)
        }
    }
    
    func getPhotoData(withRequest request: SampleGraphRequest, completion: @escaping (Data?, Error?) -> Void) {
        getMetaData(withRequest: request) {
            (json: [String : Any]?, error: Error?) in
            
            if json == nil || error != nil {
                completion(nil, error)
                return
            }
            
            request.getData(path: "me/photo/$value", completion: {
                (data: Data?, error: Error?) in
                completion(data, error)
            })
        }
    }
    
    
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalFileAttributeKeyDictionary(_ input: [String: Any]?) -> [FileAttributeKey: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (FileAttributeKey(rawValue: key), value)})
}
