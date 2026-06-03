//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.

import Foundation

/// Convenience extension for extracting error from Result when success was already handled.
internal extension Result
{
    /// Returns the error if this is a `.failure`, otherwise nil.
    var failureValue: Failure?
    {
        if case .failure(let error) = self { return error }
        return nil
    }
}
