//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SessionStatsTests: XCTestCase {
    func testEmptySessionsReportZeroProgressAndIncomplete() {
        let stats = SessionStats(photos: [], categories: [])

        XCTAssertEqual(stats.totalCount, 0)
        XCTAssertEqual(stats.sortedCount, 0)
        XCTAssertEqual(stats.remainingCount, 0)
        XCTAssertEqual(stats.progress, 0)
        XCTAssertEqual(stats.progressPercent, 0)
        XCTAssertFalse(stats.isComplete)
        XCTAssertTrue(stats.categoryCounts.isEmpty)
        XCTAssertEqual(stats.usedCategoryCount, 0)
    }

    func testMixedPhotosProduceCountsAndLookups() {
        let cats = Category(name: "Cats", shortcut: ShortcutKey("c")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Cats"))
        let dogs = Category(name: "Dogs", shortcut: ShortcutKey("d")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Dogs"))
        let birds = Category(name: "Birds", shortcut: ShortcutKey("b")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Birds"))
        let photos = [
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/a.jpg"), status: .categorized(cats.id)),
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/b.jpg"), status: .categorized(cats.id)),
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/c.jpg"), status: .categorized(dogs.id)),
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/d.jpg"))
        ]

        let stats = SessionStats(photos: photos, categories: [cats, dogs, birds])

        XCTAssertEqual(stats.totalCount, 4)
        XCTAssertEqual(stats.sortedCount, 3)
        XCTAssertEqual(stats.remainingCount, 1)
        XCTAssertEqual(stats.progress, 0.75, accuracy: 0.001)
        XCTAssertEqual(stats.progressPercent, 75)
        XCTAssertFalse(stats.isComplete)
        XCTAssertEqual(stats.categoryCounts.map { "\($0.category.name):\($0.count)" }, ["Cats:2", "Dogs:1", "Birds:0"])
        XCTAssertEqual(stats.countByCategoryID[cats.id], 2)
        XCTAssertEqual(stats.countByCategoryID[dogs.id], 1)
        XCTAssertNil(stats.countByCategoryID[birds.id])
        XCTAssertEqual(stats.usedCategoryCount, 2)
        XCTAssertEqual(stats.categoriesByID[cats.id], cats)
    }

    func testEquatableIncludesCategoryOrderingAndMetadata() {
        let cats = Category(name: "Cats", shortcut: ShortcutKey("c")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Cats"))
        let renamedCats = Category(id: cats.id, name: "Kittens", shortcut: ShortcutKey("k")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Kittens"))
        let dogs = Category(name: "Dogs", shortcut: ShortcutKey("d")!, destinationFolderURL: URL(fileURLWithPath: "/tmp/Dogs"))
        let photos = [
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/a.jpg"), status: .categorized(cats.id)),
            PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/b.jpg"), status: .categorized(dogs.id))
        ]

        XCTAssertEqual(
            SessionStats(photos: photos, categories: [cats, dogs]),
            SessionStats(photos: photos, categories: [cats, dogs])
        )
        XCTAssertNotEqual(
            SessionStats(photos: photos, categories: [cats, dogs]),
            SessionStats(photos: photos, categories: [dogs, cats])
        )
        XCTAssertNotEqual(
            SessionStats(photos: photos, categories: [cats, dogs]),
            SessionStats(photos: photos, categories: [renamedCats, dogs])
        )
    }
}
