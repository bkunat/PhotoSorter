//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class ShortcutKeyTests: XCTestCase {
    func testAcceptsOneLetterOrDigitAndStoresLowercase() throws {
        XCTAssertEqual(try XCTUnwrap(ShortcutKey("D")).rawValue, "d")
        XCTAssertEqual(try XCTUnwrap(ShortcutKey("7")).rawValue, "7")
    }

    func testTrimsWhitespace() throws {
        XCTAssertEqual(try XCTUnwrap(ShortcutKey("  a\n")).rawValue, "a")
    }

    func testRejectsUnsupportedValues() {
        ["", "ab", "/", " ", "\n", "🙂"].forEach { value in
            XCTAssertNil(ShortcutKey(value), value)
        }
    }

    func testDisplayValueUppercasesRawValue() throws {
        XCTAssertEqual(try XCTUnwrap(ShortcutKey("d")).displayValue, "D")
    }

    func testEqualityAndHashTreatDifferentInputCasingAsSameKey() throws {
        let lower = try XCTUnwrap(ShortcutKey("d"))
        let upper = try XCTUnwrap(ShortcutKey("D"))

        XCTAssertEqual(lower, upper)
        XCTAssertEqual(Set([lower, upper]).count, 1)
    }
}
