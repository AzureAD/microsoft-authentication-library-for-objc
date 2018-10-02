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

protocol GraphRequesting
{
    func getJSON(path: String, completion: @escaping (_ json: [String:Any]?, Error?) -> Void)
    func getData(path: String, completion: @escaping (_ data: Data?, Error?) -> Void)
}

class SampleGraphRequest: GraphRequesting {
    
    let kSampleGraphErrorDomain: NSErrorDomain = "SampleGraphErrorDomain"
    
    var token: String
    
    class func graphURL(with path:String) -> URL? {
        return URL(string: "https://graph.microsoft.com/beta/\(path)")
    }
    
    init(withToken token: String) {
        self.token = token
    }
    
    func getJSON(path: String, completion: @escaping (_ json: [String:Any]?, Error?) -> Void) {
        
        getData(path: path) {
            (data, error) in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            do {
                let resultJson = try JSONSerialization.jsonObject(with: data!, options: []) as! [String:Any]
                completion(resultJson, nil)
                return
            }
            catch let error {
                completion(nil, error)
                return
            }
        }
    }
    
    func getData(path: String, completion: @escaping (_ data: Data?, Error?) -> Void) {
        let urlRequest = NSMutableURLRequest()
        urlRequest.url = SampleGraphRequest.graphURL(with: path)
        urlRequest.httpMethod = "GET"
        urlRequest.allHTTPHeaderFields = [ "Authorization" : "Bearer \(token)" ]
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest as URLRequest) {
            (data: Data?, response: URLResponse?, error: Error?) in

            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                completion(nil, error)
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(data, nil)
                return
            }
            else {
                do {
                    let resultJson = try JSONSerialization.jsonObject(with: data!, options: []) as! [String:Any]
                    
                    completion(nil, NSError(domain: self.kSampleGraphErrorDomain as String,
                                            code: (response as? HTTPURLResponse)!.statusCode,
                                            userInfo: resultJson["error"] as? [String : Any]))
                    return
                }
                catch let error {
                    completion(nil, error)
                    return
                }
            }
        }
        task.resume()
    }
}
