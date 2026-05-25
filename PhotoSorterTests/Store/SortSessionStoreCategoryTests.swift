//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SortSessionStoreCategoryTests: XCTestCase {
    func testOpenCategorySheetWithoutSelectedFolderPresentsNoFolderSelected() {
        let store = makeStore()

        store.openCategorySheet()

        XCTAssertEqual(store.activeAlert?.title, SessionError.noFolderSelected.alertTitle)
    }

    func testOpenCategorySheetWithMissingIDPresentsInvalidCategory() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)

        store.openCategorySheet(for: UUID())

        XCTAssertEqual(store.activeAlert?.title, SessionError.invalidCategory.alertTitle)
    }

    func testCreateCategoryWithoutFolderThrowsNoFolderSelected() {
        XCTAssertThrowsError(try makeStore().createCategory(name: "Dogs", shortcut: "d")) { error in
            XCTAssertEqual(error as? SessionError, .noFolderSelected)
        }
    }

    func testCreateCategoryAppendsDestinationUnderSelectedFolderAndDismissesSheet() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        store.openCategorySheet()

        try store.createCategory(name: " Dogs ", shortcut: "D")

        XCTAssertEqual(store.categories.map(\.name), ["Dogs"])
        XCTAssertEqual(store.categories.first?.shortcut, ShortcutKey("d"))
        XCTAssertEqual(store.categories.first?.destinationFolderURL, directoryURL.appendingPathComponent("Dogs", isDirectory: true))
        XCTAssertFalse(store.isPresentingCategorySheet)
    }

    func testCreateCategoryRejectsInvalidDuplicateAndUnsupportedInputs() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        try store.createCategory(name: "Dogs", shortcut: "d")

        XCTAssertThrowsError(try store.createCategory(name: "../Outside", shortcut: "o")) { XCTAssertEqual($0 as? SessionError, .invalidCategoryName("../Outside")) }
        XCTAssertThrowsError(try store.createCategory(name: "dogs", shortcut: "g")) { XCTAssertEqual($0 as? SessionError, .duplicateCategoryName("dogs")) }
        XCTAssertThrowsError(try store.createCategory(name: "Cats", shortcut: "D")) { XCTAssertEqual($0 as? SessionError, .duplicateShortcut("D")) }
        XCTAssertThrowsError(try store.createCategory(name: "Birds", shortcut: "/")) { XCTAssertEqual($0 as? SessionError, .unsupportedShortcut) }
    }

    func testUpdateCategoryWithoutFolderThrowsNoFolderSelected() {
        XCTAssertThrowsError(try makeStore().updateCategory(id: UUID(), name: "Dogs", shortcut: "d")) { error in
            XCTAssertEqual(error as? SessionError, .noFolderSelected)
        }
    }

    func testUpdateCategoryWithMissingIDThrowsInvalidCategory() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)

        XCTAssertThrowsError(try store.updateCategory(id: UUID(), name: "Dogs", shortcut: "d")) { error in
            XCTAssertEqual(error as? SessionError, .invalidCategory)
        }
    }

    func testUpdateCategoryValidatesDuplicatesWhileExcludingEditedCategory() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        try store.createCategory(name: "Dogs", shortcut: "d")
        try store.createCategory(name: "Cats", shortcut: "c")
        let dogs = try XCTUnwrap(store.categories.first { $0.name == "Dogs" })
        let cats = try XCTUnwrap(store.categories.first { $0.name == "Cats" })

        try store.updateCategory(id: dogs.id, name: "dogs", shortcut: "D")
        XCTAssertThrowsError(try store.updateCategory(id: dogs.id, name: "Cats", shortcut: "d")) { XCTAssertEqual($0 as? SessionError, .duplicateCategoryName("Cats")) }
        XCTAssertThrowsError(try store.updateCategory(id: dogs.id, name: "Dogs", shortcut: "c")) { XCTAssertEqual($0 as? SessionError, .duplicateShortcut("C")) }
        XCTAssertEqual(store.categories.first { $0.id == cats.id }?.name, "Cats")
    }

    func testUpdateCategoryRenamesBackingFolderWhenItExists() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldFolderURL = try createDirectory(named: "Dogs", in: directoryURL)
        createFile(named: "a.jpg", in: oldFolderURL)
        let store = makeStore()
        try store.loadExistingProject(from: directoryURL)
        let category = try XCTUnwrap(store.categories.first)

        try store.updateCategory(id: category.id, name: "Pets", shortcut: "p")

        let newFolderURL = directoryURL.appendingPathComponent("Pets", isDirectory: true)
        XCTAssertFalse(itemExists(at: oldFolderURL))
        XCTAssertTrue(fileExists(at: newFolderURL.appendingPathComponent("a.jpg")))
        XCTAssertEqual(store.categories.first?.destinationFolderURL, newFolderURL)
    }

    func testUpdateCategoryRemapsCategorizedPhotoURLsAndUndoDestinationURLsAfterRename() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        try store.createCategory(name: "Dogs", shortcut: "d")
        let category = try XCTUnwrap(store.categories.first)
        try store.categorizeCurrentPhoto(with: category.id)

        try store.updateCategory(id: category.id, name: "Pets", shortcut: "p")

        let newPhotoURL = directoryURL.appendingPathComponent("Pets/a.jpg")
        XCTAssertEqual(store.photos.first?.currentURL, newPhotoURL)
        XCTAssertEqual(store.undoHistory.last?.destinationURL, newPhotoURL)
    }

    func testFailedCategoryRenameLeavesStateUnchanged() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        try store.createCategory(name: "Dogs", shortcut: "d")
        let category = try XCTUnwrap(store.categories.first)
        try store.categorizeCurrentPhoto(with: category.id)
        try createDirectory(named: "Pets", in: directoryURL)
        let oldCategory = try XCTUnwrap(store.categories.first)
        let oldPhotos = store.photos
        let oldUndoHistory = store.undoHistory

        XCTAssertThrowsError(try store.updateCategory(id: category.id, name: "Pets", shortcut: "p"))

        XCTAssertEqual(store.categories.first, oldCategory)
        XCTAssertEqual(store.photos, oldPhotos)
        XCTAssertEqual(store.undoHistory, oldUndoHistory)
    }
}
