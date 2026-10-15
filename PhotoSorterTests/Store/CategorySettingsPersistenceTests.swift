//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class CategorySettingsPersistenceTests: XCTestCase {
    func testUnusedCategoriesAndCustomShortcutsSurviveReopening() throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directory)
        let first = makeStore(userDefaults: defaults)
        try first.loadSession(from: directory)
        try first.createCategory(name: "Dogs", shortcut: "9")
        let category = try XCTUnwrap(first.categories.first)
        XCTAssertFalse(itemExists(at: category.destinationFolderURL))

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadSession(from: directory)

        XCTAssertEqual(reopened.categories, [category])
        XCTAssertEqual(reopened.photos.map(\.filename), ["a.jpg"])
    }

    func testRestoredCategoriesReadCurrentPhotoLocationsFromDisk() throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        let photo = createFile(named: "a.jpg", in: directory)
        let first = makeStore(userDefaults: defaults)
        try first.loadSession(from: directory)
        try first.createCategory(name: "Dogs", shortcut: "9")
        let dogs = try XCTUnwrap(first.categories.first)
        try FileManager.default.createDirectory(at: dogs.destinationFolderURL, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: photo, to: dogs.destinationFolderURL.appendingPathComponent("a.jpg"))

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadSession(from: directory)

        XCTAssertEqual(reopened.photos.count, 1)
        XCTAssertEqual(reopened.photos[0].status, .categorized(dogs.id))
        XCTAssertTrue(reopened.undoHistory.isEmpty)
    }

    func testImportPreservesSavedKeysBeforeAssigningNewFolders() throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        let first = makeStore(userDefaults: defaults)
        try first.loadSession(from: directory)
        try first.createCategory(name: "Dogs", shortcut: "c")
        try createDirectory(named: "Cats", in: directory)

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadExistingProject(from: directory)

        XCTAssertEqual(reopened.categories.first { $0.name == "Dogs" }?.shortcut.rawValue, "c")
        XCTAssertNotEqual(reopened.categories.first { $0.name == "Cats" }?.shortcut.rawValue, "c")
        XCTAssertEqual(Set(reopened.categories.map(\.shortcut)).count, 2)
    }

    func testRenameAndChangedShortcutPersist() throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        let first = makeStore(userDefaults: defaults)
        try first.loadSession(from: directory)
        try first.createCategory(name: "Dogs", shortcut: "d")
        let id = try XCTUnwrap(first.categories.first?.id)
        try first.updateCategory(id: id, name: "Animals", shortcut: "7")

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadSession(from: directory)

        XCTAssertEqual(reopened.categories.map(\.name), ["Animals"])
        XCTAssertEqual(reopened.categories.first?.shortcut.rawValue, "7")
        XCTAssertEqual(reopened.categories.first?.id, id)
    }

    func testSettingsOutliveRecentDirectoryLimit() throws {
        let defaults = makeTestUserDefaults()
        let firstDirectory = try makeTemporaryDirectory()
        let store = makeStore(userDefaults: defaults)
        try store.loadSession(from: firstDirectory)
        try store.createCategory(name: "Keep", shortcut: "8")
        for _ in 0..<9 { try store.loadSession(from: makeTemporaryDirectory()) }
        XCTAssertFalse(store.recentDirectories.contains { $0.path == firstDirectory.path })

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadSession(from: firstDirectory)

        XCTAssertEqual(reopened.categories.map(\.name), ["Keep"])
        XCTAssertEqual(reopened.categories.first?.shortcut.rawValue, "8")
    }

    func testKnownFlatFolderReopensWithoutImportingUnrelatedSubfolders() async throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        let first = makeStore(userDefaults: defaults)
        try first.loadSession(from: directory)
        try first.createCategory(name: "Dogs", shortcut: "d")
        let unrelated = try createDirectory(named: "Unrelated", in: directory)
        createFile(named: "other.jpg", in: unrelated)

        let reopened = makeStore(userDefaults: defaults)
        reopened.openDirectory(directory)
        try await waitForLoading(reopened)

        XCTAssertNil(reopened.pendingProjectOpen)
        XCTAssertEqual(reopened.categories.map(\.name), ["Dogs"])
        XCTAssertTrue(reopened.photos.isEmpty)
    }

    func testExternalCaseRenameDoesNotDuplicateCategoryOrPhotos() throws {
        let defaults = makeTestUserDefaults()
        let directory = try makeTemporaryDirectory()
        let original = try createDirectory(named: "Dogs", in: directory)
        createFile(named: "a.jpg", in: original)
        let first = makeStore(userDefaults: defaults)
        try first.loadExistingProject(from: directory)
        let categoryID = try XCTUnwrap(first.categories.first?.id)
        let temporary = directory.appendingPathComponent("Temporary")
        let renamed = directory.appendingPathComponent("dogs")
        try FileManager.default.moveItem(at: original, to: temporary)
        try FileManager.default.moveItem(at: temporary, to: renamed)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: original.path), "Requires a case-insensitive volume")

        let reopened = makeStore(userDefaults: defaults)
        try reopened.loadExistingProject(from: directory)

        XCTAssertEqual(reopened.categories.count, 1)
        XCTAssertEqual(reopened.categories.first?.name, "dogs")
        XCTAssertEqual(reopened.categories.first?.id, categoryID)
        XCTAssertEqual(reopened.photos.count, 1)
    }

    func testScannerRejectsEscapingNamesAndRepairsConflictingSavedKeys() throws {
        let directory = try makeTemporaryDirectory()
        let settings = CategorySettings(categories: [
            SavedCategory(id: UUID(), name: "../Outside", shortcut: "x"),
            SavedCategory(id: UUID(), name: "Dogs", shortcut: "d"),
            SavedCategory(id: UUID(), name: "Deer", shortcut: "d")
        ], includesOtherFolders: true)

        let session = try SessionScanner().buildSessionLoadResult(in: directory, mode: .existingProject, settings: settings)

        XCTAssertEqual(session.categories.map(\.name), ["Dogs", "Deer"])
        XCTAssertEqual(Set(session.categories.map(\.shortcut)).count, 2)
        XCTAssertTrue(session.categories.allSatisfy { $0.destinationFolderURL.deletingLastPathComponent() == directory.standardizedFileURL })
    }
}
