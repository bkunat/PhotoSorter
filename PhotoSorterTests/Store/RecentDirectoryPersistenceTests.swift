//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

final class RecentDirectoryPersistenceTests: XCTestCase {
    private let defaultsKey = "recentDirectories"

    func testPersistEmptyArrayRemovesDefaultsKey() throws {
        let userDefaults = makeTestUserDefaults()
        let persistence = RecentDirectoryPersistence(userDefaults: userDefaults)
        let directoryURL = try makeTemporaryDirectory()
        let recents = try persistence.adding(directoryURL, to: [], openedAt: Date())
        persistence.persist(recents)

        persistence.persist([])

        XCTAssertNil(userDefaults.data(forKey: defaultsKey))
    }

    func testPersistThenLoadRoundTripsValidDirectories() throws {
        let userDefaults = makeTestUserDefaults()
        let persistence = RecentDirectoryPersistence(userDefaults: userDefaults)
        let directoryURL = try makeTemporaryDirectory()
        let recents = try persistence.adding(directoryURL, to: [], openedAt: Date(timeIntervalSince1970: 100))

        persistence.persist(recents)

        XCTAssertEqual(persistence.loadPersistedRecentDirectories().map(\.path), [directoryURL.resolvingSymlinksInPath().standardizedFileURL.path])
    }

    func testInvalidDefaultsDataIsRemovedAndLoadsEmptyList() {
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(Data([0, 1, 2]), forKey: defaultsKey)
        let persistence = RecentDirectoryPersistence(userDefaults: userDefaults)

        XCTAssertTrue(persistence.loadPersistedRecentDirectories().isEmpty)
        XCTAssertNil(userDefaults.data(forKey: defaultsKey))
    }

    func testAddingInsertsNewestFirstDeduplicatesByPathAndCapsAtEight() throws {
        let persistence = RecentDirectoryPersistence(userDefaults: makeTestUserDefaults())
        var recents: [RecentDirectory] = []
        var urls: [URL] = []
        for index in 0..<9 {
            let directoryURL = try makeTemporaryDirectory()
            urls.append(directoryURL.resolvingSymlinksInPath().standardizedFileURL)
            recents = try persistence.adding(directoryURL, to: recents, openedAt: Date(timeIntervalSince1970: Double(index)))
        }

        XCTAssertEqual(recents.count, 8)
        XCTAssertEqual(recents.first?.path, urls[8].path)
        XCTAssertFalse(recents.contains { $0.path == urls[0].path })

        recents = try persistence.adding(urls[3], to: recents, openedAt: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(recents.first?.path, urls[3].path)
        XCTAssertEqual(recents.filter { $0.path == urls[3].path }.count, 1)
    }

    func testReplacingUpdatesOnlyMatchingPath() {
        let first = RecentDirectory(displayName: "First", path: "/tmp/first", bookmarkData: Data([1]), lastOpenedAt: Date())
        let second = RecentDirectory(displayName: "Second", path: "/tmp/second", bookmarkData: Data([2]), lastOpenedAt: Date())
        let updated = RecentDirectory(displayName: "Updated", path: "/tmp/updated", bookmarkData: Data([3]), lastOpenedAt: Date())

        let recents = RecentDirectoryPersistence(userDefaults: makeTestUserDefaults()).replacing(first, with: updated, in: [first, second])

        XCTAssertEqual(recents, [updated, second])
    }

    func testRemovingRemovesByPath() {
        let first = RecentDirectory(displayName: "First", path: "/tmp/first", bookmarkData: Data([1]), lastOpenedAt: Date())
        let second = RecentDirectory(displayName: "Second", path: "/tmp/second", bookmarkData: Data([2]), lastOpenedAt: Date())

        let recents = RecentDirectoryPersistence(userDefaults: makeTestUserDefaults()).removing(first, from: [first, second])

        XCTAssertEqual(recents, [second])
    }

    func testResolvedAvailableURLReturnsUpdatedDirectoryWhenStoredNameDiffers() throws {
        let persistence = RecentDirectoryPersistence(userDefaults: makeTestUserDefaults())
        let directoryURL = try makeTemporaryDirectory()
        let recent = try persistence.adding(directoryURL, to: [], openedAt: Date()).first!
        let staleDisplay = RecentDirectory(
            displayName: "Old Name",
            path: recent.path,
            bookmarkData: recent.bookmarkData,
            lastOpenedAt: recent.lastOpenedAt
        )

        let resolution = try persistence.resolvedAvailableURL(for: staleDisplay)

        XCTAssertEqual(resolution.url.path, recent.path)
        XCTAssertEqual(resolution.updatedDirectory?.displayName, directoryURL.lastPathComponent)
    }
}
