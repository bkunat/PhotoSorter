//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

final class SessionAlertTests: XCTestCase {
    func testAlertTitleMirrorsSessionErrorAlertTitle() {
        let error = SessionError.destinationConflict("/tmp/a.jpg")

        XCTAssertEqual(SessionAlert(error: error).title, error.alertTitle)
    }

    func testMessageJoinsDescriptionAndRecoverySuggestionWithBlankLine() {
        let error = SessionError.destinationConflict("/tmp/a.jpg")

        XCTAssertEqual(
            SessionAlert(error: error).message,
            [error.errorDescription, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
        )
    }

    func testMessageContainsOnlyDescriptionWhenNoRecoverySuggestionExists() {
        let error = SessionError.noFolderSelected

        XCTAssertEqual(SessionAlert(error: error).message, error.errorDescription)
    }
}
