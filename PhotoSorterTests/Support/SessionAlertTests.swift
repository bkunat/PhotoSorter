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

    func testFailedRenameRecoveryIncludesExactPathAndFinderInstructions() {
        let path = "/tmp/Photos/.photosorter-rename-example"
        let error = SessionError.categoryRenameRecoveryRequired(name: "Dogs", recoveryPath: path, underlying: "Permission denied")
        let alert = SessionAlert(error: error)

        XCTAssertTrue(alert.message.contains(path))
        XCTAssertTrue(alert.message.contains("Go to Folder"))
        XCTAssertTrue(alert.message.contains("Permission denied"))
    }
}
