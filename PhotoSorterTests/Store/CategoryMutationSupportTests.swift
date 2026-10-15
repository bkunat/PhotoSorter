//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

final class CategoryMutationSupportTests: XCTestCase {
    private let support = CategoryMutationSupport()

    func testValidatedInputTrimsNameAndNormalizesShortcut() throws {
        let result = try support.validatedCategoryInput(name: "  Dogs\n", shortcut: " D ", categories: [], excluding: nil)

        XCTAssertEqual(result.name, "Dogs")
        XCTAssertEqual(result.shortcut, ShortcutKey("d"))
    }

    func testEmptyNamesThrow() {
        XCTAssertThrowsError(try support.validatedCategoryInput(name: "  \n", shortcut: "d", categories: [], excluding: nil)) { error in
            XCTAssertEqual(error as? SessionError, .emptyCategoryName)
        }
    }

    func testInvalidFolderNamesThrow() {
        for name in [".", "..", ".Keep", " .Hidden ", "/", "../Outside", "Family/Raw", "Dog/"] {
            XCTAssertThrowsError(try support.validatedCategoryInput(name: name, shortcut: "d", categories: [], excluding: nil), name) { error in
                XCTAssertEqual(error as? SessionError, .invalidCategoryName(name.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
    }

    func testUnsupportedShortcutsThrow() {
        for shortcut in ["", "ab", "/", "🙂"] {
            XCTAssertThrowsError(try support.validatedCategoryInput(name: "Dogs", shortcut: shortcut, categories: [], excluding: nil), shortcut) { error in
                XCTAssertEqual(error as? SessionError, .unsupportedShortcut)
            }
        }
    }

    func testDuplicateNamesAreRejectedCaseAndDiacriticInsensitively() {
        let category = Category(name: "Café", shortcut: ShortcutKey("c")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Cafe"))

        XCTAssertThrowsError(try support.validatedCategoryInput(name: "cafe", shortcut: "d", categories: [category], excluding: nil)) { error in
            XCTAssertEqual(error as? SessionError, .duplicateCategoryName("cafe"))
        }
    }

    func testDuplicateShortcutsAreRejected() {
        let category = Category(name: "Cats", shortcut: ShortcutKey("c")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Cats"))

        XCTAssertThrowsError(try support.validatedCategoryInput(name: "Dogs", shortcut: "C", categories: [category], excluding: nil)) { error in
            XCTAssertEqual(error as? SessionError, .duplicateShortcut("C"))
        }
    }

    func testDuplicatesAreAllowedForExcludedCategory() throws {
        let category = Category(name: "Cats", shortcut: ShortcutKey("c")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Cats"))

        let result = try support.validatedCategoryInput(name: "cats", shortcut: "C", categories: [category], excluding: category.id)

        XCTAssertEqual(result.name, "cats")
        XCTAssertEqual(result.shortcut, ShortcutKey("c"))
    }

    func testRenameNoOpsWhenPathsAreIdenticalOrOldFolderDoesNotExist() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = directoryURL.appendingPathComponent("Dogs", isDirectory: true)
        let missingURL = directoryURL.appendingPathComponent("Missing", isDirectory: true)

        try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: oldURL, categoryName: "Dogs")
        try support.renameCategoryDirectoryIfNeeded(from: missingURL, to: directoryURL.appendingPathComponent("New", isDirectory: true), categoryName: "Missing")

        XCTAssertFalse(itemExists(at: oldURL))
        XCTAssertFalse(itemExists(at: missingURL))
    }

    func testRenameThrowsWhenTargetFolderExistsAndChangeIsNotCaseOnly() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = try createDirectory(named: "Dogs", in: directoryURL)
        let newURL = try createDirectory(named: "Cats", in: directoryURL)

        XCTAssertThrowsError(try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: newURL, categoryName: "Dogs")) { error in
            XCTAssertEqual(error as? SessionError, .categoryFolderConflict(newURL.path))
        }
        XCTAssertTrue(directoryExists(at: oldURL))
    }

    func testCaseOnlyRenameSucceedsThroughTemporaryFolder() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = try createDirectory(named: "Dogs", in: directoryURL)
        let newURL = directoryURL.appendingPathComponent("dogs", isDirectory: true)
        createFile(named: "a.jpg", in: oldURL)

        try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: newURL, categoryName: "Dogs")

        XCTAssertTrue(directoryExists(at: newURL))
        XCTAssertTrue(fileExists(at: newURL.appendingPathComponent("a.jpg")))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directoryURL.path).contains("dogs"))
    }

    func testAccentOnlyRenameRejectsDifferentExistingFolder() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = try createDirectory(named: "Cafe", in: directoryURL)
        let newURL = try createDirectory(named: "Café", in: directoryURL)
        let originalPhotoURL = createFile(named: "a.jpg", in: oldURL)

        XCTAssertThrowsError(try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: newURL, categoryName: "Cafe")) {
            XCTAssertEqual($0 as? SessionError, .categoryFolderConflict(newURL.path))
        }

        XCTAssertTrue(fileExists(at: originalPhotoURL))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directoryURL.path).count, 2)
    }

    func testFailedSecondRenameRestoresOriginalFolder() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = try createDirectory(named: "Dogs", in: directoryURL)
        let newURL = directoryURL.appendingPathComponent("dogs", isDirectory: true)
        let originalPhotoURL = createFile(named: "a.jpg", in: oldURL)
        let fileManager = RenameFailureFileManager(originalURL: oldURL, renamedURL: newURL, failedMoves: [2])
        let support = CategoryMutationSupport(fileManager: fileManager)

        XCTAssertThrowsError(try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: newURL, categoryName: "Dogs")) {
            guard case .categoryRenameFailed = $0 as? SessionError else {
                return XCTFail("Expected rename failure, got \($0)")
            }
        }

        XCTAssertTrue(fileExists(at: originalPhotoURL))
        XCTAssertEqual(fileManager.moveCount, 3)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directoryURL.path), ["Dogs"])
    }

    func testFailedRenameAndRollbackReportsLocationContainingPhotos() throws {
        let directoryURL = try makeTemporaryDirectory()
        let oldURL = try createDirectory(named: "Dogs", in: directoryURL)
        let newURL = directoryURL.appendingPathComponent("dogs", isDirectory: true)
        createFile(named: "a.jpg", in: oldURL)
        let fileManager = RenameFailureFileManager(originalURL: oldURL, renamedURL: newURL, failedMoves: [2, 3])
        let support = CategoryMutationSupport(fileManager: fileManager)

        XCTAssertThrowsError(try support.renameCategoryDirectoryIfNeeded(from: oldURL, to: newURL, categoryName: "Dogs")) {
            guard case let .categoryRenameRecoveryRequired(name, recoveryPath, _) = $0 as? SessionError else {
                return XCTFail("Expected recoverable location, got \($0)")
            }
            XCTAssertEqual(name, "Dogs")
            XCTAssertTrue(self.fileExists(at: URL(fileURLWithPath: recoveryPath).appendingPathComponent("a.jpg")))
        }

        XCTAssertEqual(fileManager.moveCount, 3)
    }

    func testRemapPreservesBothStatusesAndUpdatesUndoSourceForReassignment() {
        let rootURL = URL(fileURLWithPath: "/tmp/PhotoSorter")
        let oldURL = rootURL.appendingPathComponent("Dogs", isDirectory: true)
        let newURL = rootURL.appendingPathComponent("Pets", isDirectory: true)
        let dogsID = UUID()
        let catsID = UUID()
        let destinationURL = rootURL.appendingPathComponent("Cats/a.jpg")
        var photos = [PhotoItem(originalURL: oldURL.appendingPathComponent("a.jpg"), currentURL: destinationURL, status: .categorized(catsID))]
        var actions = [SortAction(
            photoID: photos[0].id,
            sourceURL: oldURL.appendingPathComponent("a.jpg"),
            destinationURL: destinationURL,
            previousStatus: .categorized(dogsID),
            nextStatus: .categorized(catsID)
        )]

        support.remapURLsForRenamedCategory(categoryID: dogsID, oldDirectoryURL: oldURL, newDirectoryURL: newURL, photos: &photos, undoHistory: &actions)

        XCTAssertEqual(actions[0].sourceURL, newURL.appendingPathComponent("a.jpg"))
        XCTAssertEqual(actions[0].destinationURL, destinationURL)
        XCTAssertEqual(actions[0].previousStatus, .categorized(dogsID))
        XCTAssertEqual(actions[0].nextStatus, .categorized(catsID))
        XCTAssertEqual(photos[0].currentURL, destinationURL)
    }

    func testRemapURLsForRenamedCategoryUpdatesOnlyMatchingPhotosAndUndoActions() {
        let rootURL = URL(fileURLWithPath: "/tmp/PhotoSorter")
        let oldURL = rootURL.appendingPathComponent("Cat", isDirectory: true)
        let newURL = rootURL.appendingPathComponent("Feline", isDirectory: true)
        let catID = UUID()
        let dogID = UUID()
        var photos = [
            PhotoItem(originalURL: rootURL.appendingPathComponent("a.jpg"), currentURL: oldURL.appendingPathComponent("a.jpg"), status: .categorized(catID)),
            PhotoItem(originalURL: rootURL.appendingPathComponent("b.jpg"), currentURL: rootURL.appendingPathComponent("Dog/b.jpg"), status: .categorized(dogID))
        ]
        var undoHistory = [
            SortAction(photoID: photos[0].id, categoryID: catID, sourceURL: rootURL.appendingPathComponent("a.jpg"), destinationURL: oldURL.appendingPathComponent("a.jpg")),
            SortAction(photoID: photos[1].id, categoryID: dogID, sourceURL: rootURL.appendingPathComponent("b.jpg"), destinationURL: rootURL.appendingPathComponent("Dog/b.jpg"))
        ]

        support.remapURLsForRenamedCategory(categoryID: catID, oldDirectoryURL: oldURL, newDirectoryURL: newURL, photos: &photos, undoHistory: &undoHistory)

        XCTAssertEqual(photos[0].currentURL, newURL.appendingPathComponent("a.jpg"))
        XCTAssertEqual(photos[1].currentURL, rootURL.appendingPathComponent("Dog/b.jpg"))
        XCTAssertEqual(undoHistory[0].destinationURL, newURL.appendingPathComponent("a.jpg"))
        XCTAssertEqual(undoHistory[1].destinationURL, rootURL.appendingPathComponent("Dog/b.jpg"))
    }

    func testRemapRespectsPathBoundaries() {
        let rootURL = URL(fileURLWithPath: "/tmp/PhotoSorter")
        let oldURL = rootURL.appendingPathComponent("Cat", isDirectory: true)
        let newURL = rootURL.appendingPathComponent("Feline", isDirectory: true)
        let siblingURL = rootURL.appendingPathComponent("Cathedral", isDirectory: true)
        let categoryID = UUID()
        var photos = [
            PhotoItem(originalURL: siblingURL.appendingPathComponent("a.jpg"), currentURL: siblingURL.appendingPathComponent("a.jpg"), status: .categorized(categoryID))
        ]
        var undoHistory = [
            SortAction(photoID: photos[0].id, categoryID: categoryID, sourceURL: rootURL.appendingPathComponent("a.jpg"), destinationURL: siblingURL.appendingPathComponent("a.jpg"))
        ]

        support.remapURLsForRenamedCategory(categoryID: categoryID, oldDirectoryURL: oldURL, newDirectoryURL: newURL, photos: &photos, undoHistory: &undoHistory)

        XCTAssertEqual(photos[0].currentURL, siblingURL.appendingPathComponent("a.jpg"))
        XCTAssertEqual(undoHistory[0].destinationURL, siblingURL.appendingPathComponent("a.jpg"))
    }
}

private final class RenameFailureFileManager: FileManager, @unchecked Sendable {
    let originalURL: URL
    let renamedURL: URL
    let failedMoves: Set<Int>
    private(set) var moveCount = 0

    init(originalURL: URL, renamedURL: URL, failedMoves: Set<Int>) {
        self.originalURL = originalURL
        self.renamedURL = renamedURL
        self.failedMoves = failedMoves
        super.init()
    }

    override func fileExists(atPath path: String) -> Bool {
        // Model a case-insensitive volume even when the test runs on a case-sensitive one.
        super.fileExists(atPath: path == renamedURL.path ? originalURL.path : path)
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try super.attributesOfItem(atPath: path == renamedURL.path ? originalURL.path : path)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveCount += 1
        if failedMoves.contains(moveCount) {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
