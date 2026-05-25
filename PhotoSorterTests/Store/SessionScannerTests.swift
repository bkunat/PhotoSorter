//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

final class SessionScannerTests: XCTestCase {
    func testScanPhotosIncludesSupportedExtensionsCaseInsensitively() throws {
        let directoryURL = try makeTemporaryDirectory()
        ["a.jpg", "b.JPEG", "c.PNG", "d.HEIC"].forEach { createFile(named: $0, in: directoryURL) }

        let photos = try SessionScanner().scanPhotos(in: directoryURL)

        XCTAssertEqual(photos.map(\.filename), ["a.jpg", "b.JPEG", "c.PNG", "d.HEIC"])
    }

    func testScanPhotosIgnoresUnsupportedHiddenDirectoriesAndNestedFiles() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "ignore.txt", in: directoryURL)
        createFile(named: ".hidden.jpg", in: directoryURL)
        let nestedDirectoryURL = try createDirectory(named: "Nested", in: directoryURL)
        createFile(named: "nested.jpg", in: nestedDirectoryURL)
        try createDirectory(named: "folder.png", in: directoryURL)

        let photos = try SessionScanner().scanPhotos(in: directoryURL)

        XCTAssertEqual(photos.map(\.filename), ["a.jpg"])
    }

    func testScanPhotosSortsByLocalizedStandardFilenameOrder() throws {
        let directoryURL = try makeTemporaryDirectory()
        ["photo 10.jpg", "photo 2.jpg", "photo 1.jpg"].forEach { createFile(named: $0, in: directoryURL) }

        let photos = try SessionScanner().scanPhotos(in: directoryURL)

        XCTAssertEqual(photos.map(\.filename), ["photo 1.jpg", "photo 2.jpg", "photo 10.jpg"])
    }

    func testTopLevelOnlyResultReturnsRootPhotosAndCounts() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "b.png", in: directoryURL)
        createFile(named: "a.jpg", in: directoryURL)
        let nestedDirectoryURL = try createDirectory(named: "Nested", in: directoryURL)
        createFile(named: "nested.jpg", in: nestedDirectoryURL)

        let result = try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .topLevelOnly)

        XCTAssertEqual(result.photos.map(\.filename), ["a.jpg", "b.png"])
        XCTAssertTrue(result.categories.isEmpty)
        XCTAssertEqual(result.uncategorizedCount, 2)
        XCTAssertEqual(result.categorizedCount, 0)
        XCTAssertEqual(result.initialPhotoIndex, 0)
    }

    func testExistingProjectConvertsImmediateSubdirectoriesIntoCategoriesInFilenameOrder() throws {
        let directoryURL = try makeTemporaryDirectory()
        try createDirectory(named: "Dogs", in: directoryURL)
        try createDirectory(named: "Cats", in: directoryURL)

        let result = try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .existingProject)

        XCTAssertEqual(result.categories.map(\.name), ["Cats", "Dogs"])
    }

    func testExistingProjectAssignsShortcutsFromNamesThenFallbackCandidates() throws {
        let directoryURL = try makeTemporaryDirectory()
        ["Cactuses", "Cats", "!!!"].forEach { try! createDirectory(named: $0, in: directoryURL) }

        let result = try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .existingProject)

        XCTAssertEqual(result.categories.map(\.name), ["!!!", "Cactuses", "Cats"])
        XCTAssertEqual(result.categories.map { $0.shortcut.rawValue }, ["a", "c", "t"])
    }

    func testExistingProjectMarksNestedCategoryPhotosWithMatchingCategoryID() throws {
        let directoryURL = try makeTemporaryDirectory()
        let catsDirectoryURL = try createDirectory(named: "Cats", in: directoryURL)
        createFile(named: "cat.jpg", in: catsDirectoryURL)

        let result = try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .existingProject)

        let category = try XCTUnwrap(result.categories.first)
        XCTAssertEqual(result.photos.first?.status.assignedCategoryID, category.id)
        XCTAssertEqual(result.uncategorizedCount, 0)
        XCTAssertEqual(result.categorizedCount, 1)
    }

    func testExistingProjectIgnoresPhotosNestedDeeperThanOneCategoryFolder() throws {
        let directoryURL = try makeTemporaryDirectory()
        let catsDirectoryURL = try createDirectory(named: "Cats", in: directoryURL)
        let rawDirectoryURL = try createDirectory(named: "Raw", in: catsDirectoryURL)
        createFile(named: "ignored.jpg", in: rawDirectoryURL)

        let result = try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .existingProject)

        XCTAssertTrue(result.photos.isEmpty)
        XCTAssertEqual(result.categories.map(\.name), ["Cats"])
    }

    func testTooManyCategoryFoldersThrows() throws {
        let directoryURL = try makeTemporaryDirectory()
        for index in 0..<37 {
            try createDirectory(named: "Category \(index)", in: directoryURL)
        }

        XCTAssertThrowsError(try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: .existingProject)) { error in
            XCTAssertEqual(error as? SessionError, .tooManyCategories(categoryCount: 37, shortcutCount: 36))
        }
    }

    func testInitialPhotoIndexChoosesFirstUncategorizedFirstPhotoOrNil() {
        let categoryID = UUID()
        let categorized = PhotoItem(
            originalURL: URL(fileURLWithPath: "/tmp/a.jpg"),
            status: .categorized(categoryID)
        )
        let uncategorized = PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/b.jpg"))

        XCTAssertEqual(
            SessionLoadResult(photos: [categorized, uncategorized], categories: [], uncategorizedCount: 1, categorizedCount: 1).initialPhotoIndex,
            1
        )
        XCTAssertEqual(
            SessionLoadResult(photos: [categorized], categories: [], uncategorizedCount: 0, categorizedCount: 1).initialPhotoIndex,
            0
        )
        XCTAssertNil(SessionLoadResult(photos: [], categories: [], uncategorizedCount: 0, categorizedCount: 0).initialPhotoIndex)
    }
}
