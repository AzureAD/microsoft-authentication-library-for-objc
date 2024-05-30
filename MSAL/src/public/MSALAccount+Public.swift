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

extension MSALAccount {
    // MARK: - NSObject

    public override func isEqual(_ object: (Any)?) -> Bool {
        guard let other = object as? MSALAccount else {
            return false
        }
        return isEqualTo(user: other)
    }

    public override var hash : Int {
        let hash = 0
        // Equality of MSALAccount is depending on equality of homeAccountId or username
        // So we are not able to calculate a precise hash
        return hash
    }

    func isEqualTo(user: MSALAccount?) -> Bool {
        guard let user else {
            return false
        }

        return self.username == user.username && self.homeAccountId == user.homeAccountId
    }

    public func tenantProfiles() -> [MSALTenantProfile]? {
        return mTenantProfiles?.values as? [MSALTenantProfile]
    }

    public func addTenantProfiles(_ tenantProfiles: [MSALTenantProfile]?) {
        if (tenantProfiles?.count ?? 0) <= 0 {
            return
        }

        if mTenantProfiles == nil {
            mTenantProfiles = [String : MSALTenantProfile]()
        }

        for profile in tenantProfiles ?? [] {
            if let tenantId = profile.tenantId, mTenantProfiles?[tenantId] == nil {
                mTenantProfiles?[tenantId] = profile
            }
        }
    }
}
