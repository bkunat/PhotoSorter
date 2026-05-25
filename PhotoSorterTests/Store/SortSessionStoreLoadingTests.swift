//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SortSessionStoreLoadingTests: XCTestCase {
    func testLoadingFlatSessionPopulatesStateAndRecordsRecentDirectory() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "b.png", in: directoryURL)
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        store.undoHistory = [SortAction(photoID: UUID(), categoryID: UUID(), sourceURL: directoryURL, destinationURL: directoryURL)]
        store.activeAlert = SessionAlert(error: .noFolderSelected)
        store.activeFeedback = SessionFeedback(message: "Old", categoryID: nil, systemImage: "xmark")
        store.isPresentingCategorySheet = true

        try store.loadSession(from: directoryURL)

        XCTAssertEqual(store.selectedDirectoryURL, directoryURL)
        XCTAssertEqual(store.photos.map(\.filename), ["a.jpg", "b.png"])
        XCTAssertEqual(store.currentPhotoIndex, 0)
        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertTrue(store.undoHistory.isEmpty)
        XCTAssertNil(store.activeAlert)
        XCTAssertNil(store.activeFeedback)
        XCTAssertFalse(store.isPresentingCategorySheet)
        XCTAssertEqual(store.recentDirectories.map(\.path), [directoryURL.path])
    }

    func testLoadingExistingProjectPopulatesCategoriesCountsAndFirstUncategorizedPhoto() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "root.jpg", in: directoryURL)
        let catsDirectoryURL = try createDirectory(named: "Cats", in: directoryURL)
        createFile(named: "cat.jpg", in: catsDirectoryURL)

        let store = makeStore()
        try store.loadExistingProject(from: directoryURL)

        XCTAssertEqual(store.categories.map(\.name), ["Cats"])
        XCTAssertEqual(store.photos.map(\.filename), ["root.jpg", "cat.jpg"])
        XCTAssertEqual(store.currentPhotoIndex, 0)
        XCTAssertEqual(store.remainingUnsortedCount, 1)
        XCTAssertEqual(store.sortedCount, 1)
        XCTAssertEqual(store.photos[1].status.assignedCategoryID, store.categories.first?.id)
    }

    func testOpenDirectoryWithoutSubdirectoriesLoadsImmediately() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()

        store.openDirectory(directoryURL)

        XCTAssertEqual(store.selectedDirectoryURL, directoryURL)
        XCTAssertEqual(store.photos.map(\.filename), ["a.jpg"])
        XCTAssertNil(store.pendingProjectOpen)
    }

    func testOpenDirectoryWithImmediateSubdirectoriesSetsPendingProjectOpen() throws {
        let directoryURL = try makeTemporaryDirectory()
        try createDirectory(named: "Cats", in: directoryURL)
        let store = makeStore()

        store.openDirectory(directoryURL)

        XCTAssertNil(store.selectedDirectoryURL)
        XCTAssertEqual(store.pendingProjectOpen?.directoryURL, directoryURL)
        XCTAssertEqual(store.pendingProjectOpen?.existingCategoryCount, 1)
    }

    func testConfirmPendingProjectOpenAsExistingProjectLoadsCategoriesAndClearsPrompt() throws {
        let directoryURL = try makeTemporaryDirectory()
        let catsDirectoryURL = try createDirectory(named: "Cats", in: directoryURL)
        createFile(named: "cat.jpg", in: catsDirectoryURL)
        let store = makeStore()

        store.openDirectory(directoryURL)
        store.confirmPendingProjectOpen(asExistingProject: true)

        XCTAssertNil(store.pendingProjectOpen)
        XCTAssertEqual(store.categories.map(\.name), ["Cats"])
        XCTAssertEqual(store.sortedCount, 1)
    }

    func testConfirmPendingProjectOpenAsFlatFolderLoadsOnlyRootPhotosAndClearsPrompt() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "root.jpg", in: directoryURL)
        let catsDirectoryURL = try createDirectory(named: "Cats", in: directoryURL)
        createFile(named: "cat.jpg", in: catsDirectoryURL)
        let store = makeStore()

        store.openDirectory(directoryURL)
        store.confirmPendingProjectOpen(asExistingProject: false)

        XCTAssertNil(store.pendingProjectOpen)
        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertEqual(store.photos.map(\.filename), ["root.jpg"])
    }

    func testDismissPendingProjectOpenClearsPromptWithoutLoading() throws {
        let directoryURL = try makeTemporaryDirectory()
        try createDirectory(named: "Cats", in: directoryURL)
        let store = makeStore()

        store.openDirectory(directoryURL)
        store.dismissPendingProjectOpen()

        XCTAssertNil(store.pendingProjectOpen)
        XCTAssertNil(store.selectedDirectoryURL)
        XCTAssertTrue(store.photos.isEmpty)
    }

    func testLoadingSecondDirectoryStopsPreviousSecurityScopeOnlyAfterNewScanSucceeds() throws {
        let firstDirectoryURL = try makeTemporaryDirectory()
        let secondDirectoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: firstDirectoryURL)
        createFile(named: "b.jpg", in: secondDirectoryURL)
        let securityAccess = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: securityAccess)

        try store.loadSession(from: firstDirectoryURL)
        try store.loadSession(from: secondDirectoryURL)

        XCTAssertEqual(securityAccess.startedURLPaths, [firstDirectoryURL.path, secondDirectoryURL.path])
        XCTAssertEqual(securityAccess.stoppedURLPaths, [firstDirectoryURL.path])
        XCTAssertEqual(store.selectedDirectoryURL, secondDirectoryURL)
        XCTAssertEqual(store.photos.map(\.filename), ["b.jpg"])
    }

    func testFailedReloadStopsOnlyNewSecurityScopeAndPreservesPreviousSession() throws {
        let loadedDirectoryURL = try makeTemporaryDirectory()
        let failingDirectoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: loadedDirectoryURL)
        for index in 0..<37 {
            try createDirectory(named: "Category \(index)", in: failingDirectoryURL)
        }
        let securityAccess = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: securityAccess)

        try store.loadSession(from: loadedDirectoryURL)

        XCTAssertThrowsError(try store.loadExistingProject(from: failingDirectoryURL))

        XCTAssertEqual(store.selectedDirectoryURL, loadedDirectoryURL)
        XCTAssertEqual(store.photos.map(\.filename), ["a.jpg"])
        XCTAssertEqual(securityAccess.startedURLPaths, [loadedDirectoryURL.path, failingDirectoryURL.path])
        XCTAssertEqual(securityAccess.stoppedURLPaths, [failingDirectoryURL.path])
    }

    func testPerformConvertsSessionErrorsIntoActiveAlert() {
        let store = makeStore()

        store.perform {
            throw SessionError.noFolderSelected
        }

        XCTAssertEqual(store.activeAlert?.title, SessionError.noFolderSelected.alertTitle)
    }

    func testPerformWrapsUnknownErrorsAsUnexpected() {
        struct UnknownError: LocalizedError {
            var errorDescription: String? { "Unknown failure" }
        }
        let store = makeStore()

        store.perform {
            throw UnknownError()
        }

        XCTAssertEqual(store.activeAlert?.title, SessionError.unexpected("Unknown failure").alertTitle)
        XCTAssertEqual(store.activeAlert?.message, "Unknown failure")
    }
}
