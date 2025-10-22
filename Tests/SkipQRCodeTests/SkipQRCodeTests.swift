// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception

import XCTest
import OSLog
import Foundation
@testable import SkipQRCode

let logger: Logger = Logger(subsystem: "SkipQRCode", category: "Tests")

@available(macOS 13, *)
final class SkipQRCodeTests: XCTestCase {

    func testSkipQRCode() throws {
        logger.log("running testSkipQRCode")
        XCTAssertEqual(1 + 2, 3, "basic test")
    }

    func testDecodeType() throws {
        // load the TestData.json file from the Resources folder and decode it into a struct
        let resourceURL: URL = try XCTUnwrap(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        XCTAssertEqual("SkipQRCode", testData.testModuleName)
    }

}

struct TestData : Codable, Hashable {
    var testModuleName: String
}
