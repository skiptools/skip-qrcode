// SPDX-License-Identifier: MPL-2.0

import XCTest
import Foundation
@testable import SkipQRCode

@available(macOS 13, *)
final class QRCodeTests: XCTestCase {

    func testEncode() throws {
        let code = try QRCode("https://skip.tools")
        // Versions 1–40 are 21–177 modules, growing by 4
        XCTAssertGreaterThanOrEqual(code.size, 21)
        XCTAssertLessThanOrEqual(code.size, 177)
        XCTAssertEqual((code.size - 17) % 4, 0)
    }

    func testFinderPatterns() throws {
        let code = try QRCode("Skip")
        let last = code.size - 1
        // Dark corners of the three finder patterns, then their light separators
        XCTAssertTrue(code.isDark(x: 0, y: 0))
        XCTAssertTrue(code.isDark(x: last, y: 0))
        XCTAssertTrue(code.isDark(x: 0, y: last))
        XCTAssertTrue(code.isDark(x: 3, y: 3))
        XCTAssertFalse(code.isDark(x: 7, y: 7))
        XCTAssertFalse(code.isDark(x: last - 7, y: 7))
    }

    func testOutsideGridIsLight() throws {
        let code = try QRCode("Skip")
        XCTAssertFalse(code.isDark(x: -1, y: 0))
        XCTAssertFalse(code.isDark(x: 0, y: code.size))
    }

    func testCorrection() throws {
        let text = String(repeating: "Skip QR Code ", count: 10)
        let low = try QRCode(text, correction: .low)
        let high = try QRCode(text, correction: .high)
        XCTAssertGreaterThan(high.size, low.size)
    }

    func testUnicode() throws {
        let code = try QRCode("こんにちは 👋")
        XCTAssertGreaterThanOrEqual(code.size, 21)
    }

    func testInvalidText() throws {
        XCTAssertEqual(error(encoding: ""), QRCodeError.emptyText)
        // Byte mode holds at most 2,953 bytes, even at the lowest correction level
        XCTAssertEqual(error(encoding: String(repeating: "a", count: 3000)), QRCodeError.tooLong)
    }

    func testPNGData() throws {
        let code = try QRCode("Skip")
        let data = try XCTUnwrap(code.pngData(scale: 4))
        if !isRobolectric { // Robolectric's legacy Bitmap does not write real PNG bytes
            XCTAssertEqual(data[0], UInt8(0x89))
            XCTAssertEqual(String(data: data.subdata(in: 1..<4), encoding: .utf8), "PNG")
        }
    }

    private func error(encoding text: String) -> QRCodeError? {
        do {
            _ = try QRCode(text, correction: .low)
            return nil
        } catch {
            return error as? QRCodeError
        }
    }
}
