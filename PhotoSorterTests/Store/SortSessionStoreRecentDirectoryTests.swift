//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
final class SortSessionStoreRecentDirectoryTests: XCTestCase {
    func testLoadingDirectoriesStoresRecentsMostRecentFirst() throws {
        let firstURL = try makeTemporaryDirectory()
        let secondURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: firstURL)
        createFile(named: "b.jpg", in: secondURL)
        let store = makeStore()

        try store.loadSession(from: firstURL)
        try store.loadSession(from: secondURL)

        XCTAssertEqual(store.recentDirectories.map(\.path), [secondURL.path, firstURL.path])
    }

    func testReopeningRecentDirectoryMovesItToFrontInsteadOfDuplicating() throws {
        let firstURL = try makeTemporaryDirectory()
        let secondURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: firstURL)
        createFile(named: "b.jpg", in: secondURL)
        let store = makeStore()

        try store.loadSession(from: firstURL)
        try store.loadSession(from: secondURL)
        try store.loadSession(from: firstURL)

        XCTAssertEqual(store.recentDirectories.map(\.path), [firstURL.path, secondURL.path])
    }

    func testRecentsAreCappedAtEightEntries() throws {
        let store = makeStore()
        var urls: [URL] = []
        for index in 0..<9 {
            let directoryURL = try makeTemporaryDirectory()
            createFile(named: "\(index).jpg", in: directoryURL)
            urls.append(directoryURL)
            try store.loadSession(from: directoryURL)
        }

        XCTAssertEqual(store.recentDirectories.count, 8)
        XCTAssertEqual(store.recentDirectories.first?.path, urls[8].path)
        XCTAssertFalse(store.recentDirectories.contains { $0.path == urls[0].path })
    }

    func testNewStoreLoadsPersistedRecentDirectoriesFromSuppliedUserDefaults() throws {
        let userDefaults = makeTestUserDefaults()
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let firstStore = makeStore(userDefaults: userDefaults)
        try firstStore.loadSession(from: directoryURL)

        let secondStore = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(secondStore.recentDirectories.map(\.path), [directoryURL.path])
    }

    func testMissingRecentFoldersArePrunedWhenPersistenceLoads() throws {
        let userDefaults = makeTestUserDefaults()
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let firstStore = makeStore(userDefaults: userDefaults)
        try firstStore.loadSession(from: directoryURL)
        try FileManager.default.removeItem(at: directoryURL)

        let secondStore = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(secondStore.recentDirectories.isEmpty)
    }

    func testOpenRecentDirectoryRestoresSessionFromPersistedBookmark() throws {
        let userDefaults = makeTestUserDefaults()
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "b.png", in: directoryURL)
        let firstStore = makeStore(userDefaults: userDefaults)
        try firstStore.loadSession(from: directoryURL)
        let secondStore = makeStore(userDefaults: userDefaults)
        let recent = try XCTUnwrap(secondStore.recentDirectories.first)

        secondStore.openRecentDirectory(recent)

        XCTAssertEqual(secondStore.selectedDirectoryURL?.path, directoryURL.path)
        XCTAssertEqual(secondStore.photos.map(\.filename), ["a.jpg", "b.png"])
        XCTAssertNil(secondStore.activeAlert)
    }

    func testUnavailableRecentDirectoriesAreRemovedAndPresentedAsAlert() {
        let store = makeStore()
        let recent = RecentDirectory(displayName: "Missing", path: "/tmp/missing", bookmarkData: Data([1, 2, 3]), lastOpenedAt: Date())
        store.recentDirectories = [recent]

        store.openRecentDirectory(recent)

        XCTAssertTrue(store.recentDirectories.isEmpty)
        XCTAssertEqual(store.activeAlert?.title, SessionError.recentDirectoryUnavailable("Missing").alertTitle)
    }
}
