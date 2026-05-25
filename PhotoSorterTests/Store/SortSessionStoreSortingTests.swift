//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SortSessionStoreSortingTests: XCTestCase {
    func testCategorizeCurrentPhotoMovesRootPhotoAndAdvancesToNextUnsorted() throws {
        let directoryURL = try makeTemporaryDirectory()
        let originalURL = createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "b.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)

        try store.categorizeCurrentPhoto(with: category.id)

        let movedURL = directoryURL.appendingPathComponent("Dogs/a.jpg")
        XCTAssertFalse(itemExists(at: originalURL))
        XCTAssertTrue(fileExists(at: movedURL))
        XCTAssertEqual(store.photos[0].currentURL, movedURL)
        XCTAssertEqual(store.photos[0].status, .categorized(category.id))
        XCTAssertEqual(store.undoHistory.last?.destinationURL, movedURL)
        XCTAssertEqual(store.currentPhotoIndex, 1)
        XCTAssertEqual(store.activeFeedback?.message, "Moved a.jpg to Dogs")
    }

    func testSortingLastRemainingPhotoMarksSessionComplete() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)

        try store.categorizeCurrentPhoto(with: category.id)

        XCTAssertTrue(store.isComplete)
        XCTAssertEqual(store.activeFeedback?.message, "Sorting complete")
        XCTAssertNil(store.activeFeedback?.categoryID)
    }

    func testSortingWrapsToEarlierUnsortedPhotoWhenLaterPhotosAreCategorized() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "b.jpg", in: directoryURL)
        createFile(named: "c.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        try store.categorizeCurrentPhoto(with: category.id)
        store.selectPhoto(at: 2)

        try store.categorizeCurrentPhoto(with: category.id)

        XCTAssertEqual(store.currentPhotoIndex, 1)
        XCTAssertEqual(store.currentPhoto?.filename, "b.jpg")
    }

    func testCategorizeFailsWithNoCurrentPhoto() {
        let store = makeStore()

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: UUID())) { error in
            XCTAssertEqual(error as? SessionError, .noCurrentPhoto)
        }
    }

    func testCategorizeFailsWithInvalidCategory() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: UUID())) { error in
            XCTAssertEqual(error as? SessionError, .invalidCategory)
        }
    }

    func testCategorizeFailsWhenCurrentPhotoAlreadyCategorized() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        store.photos[0].status = .categorized(category.id)

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: category.id)) { error in
            XCTAssertEqual(error as? SessionError, .photoAlreadyCategorized)
        }
    }

    func testCategorizeFailsWhenSourceFileIsMissing() throws {
        let directoryURL = try makeTemporaryDirectory()
        let photoURL = createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        try FileManager.default.removeItem(at: photoURL)

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: category.id)) { error in
            XCTAssertEqual(error as? SessionError, .sourceFileMissing("a.jpg"))
        }
    }

    func testCategorizeFailsWhenDestinationFileAlreadyExists() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let dogsDirectoryURL = try createDirectory(named: "Dogs", in: directoryURL)
        createFile(named: "a.jpg", in: dogsDirectoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: category.id)) { error in
            XCTAssertEqual(error as? SessionError, .destinationConflict(dogsDirectoryURL.appendingPathComponent("a.jpg").path))
        }
        XCTAssertEqual(store.photos[0].status, .uncategorized)
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testMovePreparationFailuresPreserveState() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "Dogs", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        let oldPhotos = store.photos
        let oldUndo = store.undoHistory
        let oldIndex = store.currentPhotoIndex

        XCTAssertThrowsError(try store.categorizeCurrentPhoto(with: category.id))

        XCTAssertEqual(store.photos, oldPhotos)
        XCTAssertEqual(store.undoHistory, oldUndo)
        XCTAssertEqual(store.currentPhotoIndex, oldIndex)
    }

    func testUndoLastCategorizationMovesFileBackAndRestoresSelection() throws {
        let directoryURL = try makeTemporaryDirectory()
        let originalURL = createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        try store.categorizeCurrentPhoto(with: category.id)

        try store.undoLastCategorization()

        XCTAssertTrue(fileExists(at: originalURL))
        XCTAssertFalse(itemExists(at: directoryURL.appendingPathComponent("Dogs/a.jpg")))
        XCTAssertEqual(store.photos[0].currentURL, originalURL)
        XCTAssertEqual(store.photos[0].status, .uncategorized)
        XCTAssertEqual(store.currentPhotoIndex, 0)
        XCTAssertTrue(store.undoHistory.isEmpty)
        XCTAssertEqual(store.activeFeedback?.message, "Restored a.jpg")
    }

    func testUndoFailsWhenThereIsNoHistory() {
        XCTAssertThrowsError(try makeStore().undoLastCategorization()) { error in
            XCTAssertEqual(error as? SessionError, .nothingToUndo)
        }
    }

    func testUndoFailsWhenMovedFileIsMissing() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        try store.categorizeCurrentPhoto(with: category.id)
        try FileManager.default.removeItem(at: directoryURL.appendingPathComponent("Dogs/a.jpg"))

        XCTAssertThrowsError(try store.undoLastCategorization()) { error in
            XCTAssertEqual(error as? SessionError, .undoSourceMissing("a.jpg"))
        }
    }

    func testUndoFailsWhenOriginalPathHasConflict() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        try store.categorizeCurrentPhoto(with: category.id)
        createFile(named: "a.jpg", in: directoryURL)

        XCTAssertThrowsError(try store.undoLastCategorization()) { error in
            XCTAssertEqual(error as? SessionError, .undoConflict(directoryURL.appendingPathComponent("a.jpg").path))
        }
    }

    func testRemoveCategoryFromCurrentPhotoMovesExistingProjectPhotoBackToRootAndClearsUndoEntries() throws {
        let directoryURL = try makeTemporaryDirectory()
        let dogsDirectoryURL = try createDirectory(named: "Dogs", in: directoryURL)
        let nestedPhotoURL = createFile(named: "a.jpg", in: dogsDirectoryURL)
        let store = makeStore()
        try store.loadExistingProject(from: directoryURL)
        store.undoHistory = [
            SortAction(photoID: store.photos[0].id, categoryID: store.categories[0].id, sourceURL: directoryURL.appendingPathComponent("a.jpg"), destinationURL: nestedPhotoURL)
        ]

        try store.removeCategoryFromCurrentPhoto()

        let rootURL = directoryURL.appendingPathComponent("a.jpg")
        XCTAssertTrue(fileExists(at: rootURL))
        XCTAssertFalse(itemExists(at: nestedPhotoURL))
        XCTAssertEqual(store.photos[0].currentURL, rootURL)
        XCTAssertEqual(store.photos[0].status, .uncategorized)
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testRemoveCategoryNoMoveCaseOnlyUpdatesState() throws {
        let directoryURL = try makeTemporaryDirectory()
        let photoURL = createFile(named: "a.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)
        let category = try makeCategory(in: store)
        store.photos[0].status = .categorized(category.id)
        store.photos[0].currentURL = photoURL
        store.undoHistory = [
            SortAction(photoID: store.photos[0].id, categoryID: category.id, sourceURL: photoURL, destinationURL: photoURL)
        ]

        try store.removeCategoryFromCurrentPhoto()

        XCTAssertTrue(fileExists(at: photoURL))
        XCTAssertEqual(store.photos[0].status, .uncategorized)
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testSelectionCommandsStayWithinBoundsAndIgnoreInvalidIndexes() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "b.jpg", in: directoryURL)
        let store = try loadedStore(directoryURL: directoryURL)

        store.previousPhoto()
        XCTAssertEqual(store.currentPhotoIndex, 0)
        store.nextPhoto()
        XCTAssertEqual(store.currentPhotoIndex, 1)
        store.nextPhoto()
        XCTAssertEqual(store.currentPhotoIndex, 1)
        store.selectPhoto(at: -1)
        XCTAssertEqual(store.currentPhotoIndex, 1)
        store.selectPhoto(at: 99)
        XCTAssertEqual(store.currentPhotoIndex, 1)
        store.selectPhoto(at: 0)
        XCTAssertEqual(store.currentPhotoIndex, 0)
    }

    func testClearActiveFeedbackOnlyClearsWhenIDMatchesOrNoIDIsSupplied() {
        let store = makeStore()
        let feedback = SessionFeedback(message: "Moved", categoryID: nil, systemImage: "checkmark")
        store.activeFeedback = feedback

        store.clearActiveFeedback(matching: UUID())
        XCTAssertNotNil(store.activeFeedback)
        store.clearActiveFeedback(matching: feedback.id)
        XCTAssertNil(store.activeFeedback)

        store.activeFeedback = feedback
        store.clearActiveFeedback()
        XCTAssertNil(store.activeFeedback)
    }

    private func loadedStore(directoryURL: URL) throws -> SortSessionStore {
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        return store
    }

    private func makeCategory(in store: SortSessionStore) throws -> PhotoSorter.Category {
        try store.createCategory(name: "Dogs", shortcut: "d")
        return try XCTUnwrap(store.categories.first)
    }
}
