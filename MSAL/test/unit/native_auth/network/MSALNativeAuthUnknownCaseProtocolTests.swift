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

final class MSALNativeAuthUnknownCaseProtocolTests: XCTestCase {

    func test_decodeKnownValue() throws {
        let json = """
        {
            "main": "fish and chips",
            "withCoffee": true,
            "fruit": "apple"
        }
        """

        let data = json.data(using: .utf8)!

        let menu = try JSONDecoder().decode(ApiRestaurantMenu.self, from: data)

        XCTAssertNotNil(menu)
        XCTAssertEqual(menu.main, "fish and chips")
        XCTAssertTrue(menu.withCoffee)
        XCTAssertEqual(menu.fruit, .apple)
    }

    func test_decodingAnUnknownValue_produces_aNotNilApiModel() throws {
        let json = """
        {
            "main": "fish and chips",
            "withCoffee": true,
            "fruit": "pomelo"
        }
        """

        let data = json.data(using: .utf8)!

        let menu = try JSONDecoder().decode(ApiRestaurantMenu.self, from: data)

        XCTAssertNotNil(menu)
        XCTAssertEqual(menu.main, "fish and chips")
        XCTAssertTrue(menu.withCoffee)
        XCTAssertEqual(menu.fruit, .unknownCase)
    }
}

struct ApiRestaurantMenu: Decodable {
    let main: String
    let withCoffee: Bool
    let fruit: ApiFruitEnum
}

enum ApiFruitEnum: String, Decodable, CaseIterable, Equatable, MSALNativeAuthUnknownCaseProtocol {
    case apple = "apple"
    case banana = "banana"
    case unknownCase
}
