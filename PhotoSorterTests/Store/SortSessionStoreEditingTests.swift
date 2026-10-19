//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SortSessionStoreEditingTests: XCTestCase {
    func testEditMoveDeleteUndoRestoresBytesStatusAndSelection() throws {
        let folder = try makeTemporaryDirectory()
        let recovery = try makeTemporaryDirectory()
        let original = Data("original bytes".utf8)
        let edited = Data("edited bytes".utf8)
        let url = createFile(named: "a.jpg", in: folder, contents: original)
        createFile(named: "b.jpg", in: folder)
        let store = try loadedStore(folder: folder, recovery: recovery)
        let originalRevision = try XCTUnwrap(store.currentPhoto).contentRevision
        try store.saveEditedPhoto(data: edited, expectedCurrentData: original)
        XCTAssertNotEqual(store.currentPhoto?.contentRevision, originalRevision)
        XCTAssertEqual(try Data(contentsOf: url), edited)
        guard case let .edit(backupURL, _) = store.undoHistory[0].kind else { return XCTFail("Expected edit") }
        XCTAssertTrue(backupURL.path.hasPrefix(recovery.path))
        XCTAssertEqual(try Data(contentsOf: backupURL), original)
        try store.createCategory(name: "Dogs", shortcut: "d")
        let category = try XCTUnwrap(store.categories.first)
        try store.categorizeCurrentPhoto(with: category.id)
        store.selectPhoto(at: 0)
        try store.deleteCurrentPhoto()
        XCTAssertEqual(store.currentPhoto?.filename, "b.jpg")
        XCTAssertFalse(itemExists(at: category.destinationFolderURL.appendingPathComponent("a.jpg")))

        try store.undoLastAction()
        XCTAssertEqual(store.currentPhotoIndex, 0)
        XCTAssertEqual(store.currentPhoto?.status, .categorized(category.id))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.currentPhoto).currentURL), edited)
        try store.undoLastAction()
        XCTAssertEqual(store.currentPhoto?.status, .uncategorized)
        XCTAssertEqual(try Data(contentsOf: url), edited)
        try store.undoLastAction()
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertTrue(store.undoHistory.isEmpty)
        XCTAssertTrue(itemExists(at: backupURL))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)), ["Dogs", "a.jpg", "b.jpg"])
    }

    func testRepeatedEditsUndoInOrder() throws {
        let folder = try makeTemporaryDirectory()
        let url = createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        try store.saveEditedPhoto(data: Data("one".utf8))
        try store.saveEditedPhoto(data: Data("two".utf8))
        try store.undoLastAction()
        XCTAssertEqual(try Data(contentsOf: url), Data("one".utf8))
        try store.undoLastAction()
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
    }

    func testUndoDeletionConflictPreservesBothFilesAndHistory() throws {
        let folder = try makeTemporaryDirectory()
        let url = createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        try store.deleteCurrentPhoto()
        XCTAssertNil(store.currentPhotoIndex)
        let action = try XCTUnwrap(store.undoHistory.last)
        createFile(named: "a.jpg", in: folder, contents: Data("external".utf8))
        XCTAssertThrowsError(try store.undoLastAction()) {
            XCTAssertEqual($0 as? SessionError, .undoConflict(url.path))
        }
        XCTAssertEqual(store.undoHistory, [action])
        XCTAssertEqual(try Data(contentsOf: url), Data("external".utf8))
        XCTAssertEqual(try Data(contentsOf: action.destinationURL), Data("original".utf8))
    }

    func testExternalChangePreventsSavingAndUndoingEdit() throws {
        let folder = try makeTemporaryDirectory()
        let url = createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        XCTAssertThrowsError(try store.saveEditedPhoto(data: Data(), expectedCurrentData: Data("stale".utf8))) {
            XCTAssertEqual($0 as? SessionError, .photoChangedExternally("a.jpg"))
        }
        XCTAssertTrue(store.undoHistory.isEmpty)
        try store.saveEditedPhoto(data: Data("edited".utf8))
        try Data("external".utf8).write(to: url)
        XCTAssertThrowsError(try store.undoLastAction()) {
            XCTAssertEqual($0 as? SessionError, .photoChangedExternally("a.jpg"))
        }
        XCTAssertEqual(try Data(contentsOf: url), Data("external".utf8))
        XCTAssertEqual(store.undoHistory.count, 1)
    }

    func testRecoveryCopiesSurviveOpeningAnotherFolder() throws {
        let folder = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        try store.deleteCurrentPhoto()
        let backup = try XCTUnwrap(store.undoHistory.last).destinationURL
        try store.loadSession(from: makeTemporaryDirectory())
        XCTAssertTrue(store.undoHistory.isEmpty)
        XCTAssertEqual(try Data(contentsOf: backup), Data("original".utf8))
        let metadata = backup.deletingLastPathComponent().appendingPathComponent("source-path.txt")
        XCTAssertEqual(try String(contentsOf: metadata, encoding: .utf8), folder.appendingPathComponent("a.jpg").path)
    }

    func testRecoveryStorageInsideWorkingFolderIsRefused() throws {
        let folder = try makeTemporaryDirectory()
        let url = createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: folder.appendingPathComponent("Recovery"))
        XCTAssertThrowsError(try store.saveEditedPhoto(data: Data())) {
            XCTAssertEqual($0 as? SessionError, .recoveryStorageInWorkingDirectory)
        }
        XCTAssertThrowsError(try store.deleteCurrentPhoto())
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testBackupFailurePreventsEditingAndDeletion() throws {
        let folder = try makeTemporaryDirectory()
        let original = Data("original".utf8)
        let url = createFile(named: "a.jpg", in: folder, contents: original)
        let blockedRecovery = createFile(named: "blocked", in: try makeTemporaryDirectory())
        let store = try loadedStore(folder: folder, recovery: blockedRecovery)
        let photos = store.photos

        XCTAssertThrowsError(try store.saveEditedPhoto(data: Data("edited".utf8)))
        XCTAssertThrowsError(try store.deleteCurrentPhoto())

        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(store.photos, photos)
        XCTAssertEqual(store.currentPhotoIndex, 0)
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testSymbolicAndHardLinksAreNotEditedOrDeleted() throws {
        let folder = try makeTemporaryDirectory()
        let external = createFile(named: "external.jpg", in: try makeTemporaryDirectory(), contents: Data("original".utf8))
        let url = createFile(named: "a.jpg", in: folder)
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: external)
        XCTAssertThrowsError(try store.saveEditedPhoto(data: Data()))
        XCTAssertThrowsError(try store.deleteCurrentPhoto())
        try FileManager.default.removeItem(at: url)
        try FileManager.default.linkItem(at: external, to: url)
        XCTAssertThrowsError(try store.saveEditedPhoto(data: Data()))
        XCTAssertThrowsError(try store.deleteCurrentPhoto())
        XCTAssertEqual(try Data(contentsOf: external), Data("original".utf8))
        XCTAssertTrue(store.undoHistory.isEmpty)
    }

    func testCategoryRenamePreservesEditAndDeletionUndo() throws {
        let folder = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: folder, contents: Data("original".utf8))
        let store = try loadedStore(folder: folder, recovery: makeTemporaryDirectory())
        try store.createCategory(name: "Dogs", shortcut: "d")
        let category = try XCTUnwrap(store.categories.first)
        try store.categorizeCurrentPhoto(with: category.id)
        try store.saveEditedPhoto(data: Data("edited".utf8))
        try store.deleteCurrentPhoto()
        try store.updateCategory(id: category.id, name: "Cats", shortcut: "c")
        try store.undoLastAction()
        XCTAssertEqual(store.currentPhoto?.currentURL, folder.appendingPathComponent("Cats/a.jpg"))
        try store.undoLastAction()
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.currentPhoto).currentURL), Data("original".utf8))
        try store.undoLastAction()
        XCTAssertEqual(store.currentPhoto?.currentURL, folder.appendingPathComponent("a.jpg"))
    }

    private func loadedStore(folder: URL, recovery: URL) throws -> SortSessionStore {
        let store = SortSessionStore(userDefaults: makeTestUserDefaults(),
                                     securityScopedResourceAccess: FakeSecurityScopedResourceAccess(startResult: false),
                                     recoveryDirectoryURL: recovery)
        try store.loadSession(from: folder)
        return store
    }
}
