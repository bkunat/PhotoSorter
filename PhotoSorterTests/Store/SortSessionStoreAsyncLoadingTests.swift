//
//  PhotoSorter
//

import AppKit
import XCTest
@testable import PhotoSorter

private final class ControlledSessionScanner: SessionScanning, @unchecked Sendable {
    let blockedDirectory: URL
    let entered: XCTestExpectation
    let release = DispatchSemaphore(value: 0)
    let fails: Bool

    init(blockedDirectory: URL, entered: XCTestExpectation, fails: Bool = false) {
        self.blockedDirectory = blockedDirectory
        self.entered = entered
        self.fails = fails
    }

    func immediateSubdirectories(in directoryURL: URL) throws -> [URL] {
        try SessionScanner().immediateSubdirectories(in: directoryURL)
    }

    func buildSessionLoadResult(in directoryURL: URL, mode: SessionLoadMode, settings: CategorySettings?) throws -> SessionLoadResult {
        if directoryURL == blockedDirectory {
            entered.fulfill()
            _ = release.wait(timeout: .now() + 5)
            if fails { throw CocoaError(.fileReadNoPermission) }
        }
        return try SessionScanner().buildSessionLoadResult(in: directoryURL, mode: mode, settings: settings)
    }
}

@MainActor
final class SortSessionStoreAsyncLoadingTests: XCTestCase {
    func testCancelledScanPreservesSessionAndReleasesOnlyNewScopeWhenWorkerFinishes() async throws {
        let previous = try makeTemporaryDirectory()
        createFile(named: "previous.jpg", in: previous)
        let next = try makeTemporaryDirectory()
        createFile(named: "next.jpg", in: next)
        let entered = expectation(description: "scan started")
        let scanner = ControlledSessionScanner(blockedDirectory: next, entered: entered)
        defer { scanner.release.signal() }
        let access = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: access, scanner: scanner)
        try store.loadSession(from: previous)
        try store.createCategory(name: "Dogs", shortcut: "d")

        store.openDirectory(next)
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(store.isLoading)
        XCTAssertEqual(store.selectedDirectoryURL, previous)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "d", charactersIgnoringModifiers: "d", isARepeat: false, keyCode: 2))
        XCTAssertFalse(SessionKeyboardController().handle(event, store: store))
        XCTAssertFalse(store.canCategorizeCurrentPhoto)
        XCTAssertTrue(store.undoHistory.isEmpty)

        store.cancelLoading()
        XCTAssertFalse(store.isLoading)
        XCTAssertTrue(access.stoppedURLPaths.isEmpty)
        scanner.release.signal()
        try await waitForStop(of: next, access: access)

        XCTAssertEqual(store.selectedDirectoryURL, previous)
        XCTAssertEqual(store.photos.map(\.filename), ["previous.jpg"])
        XCTAssertEqual(access.stoppedURLPaths, [next.path])
        XCTAssertNil(store.activeAlert)
    }

    func testNewerOpenWinsEvenWhenOlderScanFinishesLater() async throws {
        let previous = try makeTemporaryDirectory()
        let slow = try makeTemporaryDirectory()
        let fast = try makeTemporaryDirectory()
        createFile(named: "slow.jpg", in: slow)
        createFile(named: "fast.jpg", in: fast)
        let entered = expectation(description: "slow scan started")
        let scanner = ControlledSessionScanner(blockedDirectory: slow, entered: entered)
        defer { scanner.release.signal() }
        let access = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: access, scanner: scanner)
        try store.loadSession(from: previous)

        store.openDirectory(slow)
        await fulfillment(of: [entered], timeout: 2)
        store.openDirectory(fast)
        try await waitForLoading(store)
        XCTAssertEqual(store.selectedDirectoryURL, fast)
        scanner.release.signal()
        try await waitForStop(of: slow, access: access)

        XCTAssertEqual(store.selectedDirectoryURL, fast)
        XCTAssertEqual(store.photos.map(\.filename), ["fast.jpg"])
        XCTAssertEqual(Set(access.stoppedURLPaths), Set([previous.path, slow.path]))
        XCTAssertFalse(access.stoppedURLPaths.contains(fast.path))
    }

    func testFailedScanPreservesSelectionUndoAndPreviousScope() async throws {
        let previous = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: previous)
        let failing = try makeTemporaryDirectory()
        let entered = expectation(description: "failing scan started")
        let scanner = ControlledSessionScanner(blockedDirectory: failing, entered: entered, fails: true)
        defer { scanner.release.signal() }
        let access = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: access, scanner: scanner)
        try store.loadSession(from: previous)
        try store.createCategory(name: "Dogs", shortcut: "d")
        try store.categorizeCurrentPhoto(with: XCTUnwrap(store.categories.first?.id))
        let photos = store.photos
        let undo = store.undoHistory

        store.openDirectory(failing)
        await fulfillment(of: [entered], timeout: 2)
        scanner.release.signal()
        try await waitForLoading(store)

        XCTAssertEqual(store.selectedDirectoryURL, previous)
        XCTAssertEqual(store.photos, photos)
        XCTAssertEqual(store.undoHistory, undo)
        XCTAssertEqual(access.stoppedURLPaths, [failing.path])
        XCTAssertNotNil(store.activeAlert)
    }

    func testExistingProjectPromptReleasesDetectionScopeAndConfirmationLoadsAsynchronously() async throws {
        let directory = try makeTemporaryDirectory()
        let category = try createDirectory(named: "Dogs", in: directory)
        createFile(named: "a.jpg", in: category)
        let access = FakeSecurityScopedResourceAccess(startResult: true)
        let store = makeStore(securityScopedResourceAccess: access)

        store.openDirectory(directory)
        try await waitForLoading(store)
        XCTAssertNotNil(store.pendingProjectOpen)
        XCTAssertEqual(access.stoppedURLPaths, [directory.path])
        store.confirmPendingProjectOpen(asExistingProject: true)
        XCTAssertTrue(store.isLoading)
        try await waitForLoading(store)

        XCTAssertEqual(store.sortedCount, 1)
        XCTAssertNil(store.pendingProjectOpen)
        XCTAssertEqual(access.startedURLPaths, [directory.path, directory.path])
        XCTAssertEqual(access.stoppedURLPaths, [directory.path])
    }

    private func waitForStop(of directory: URL, access: FakeSecurityScopedResourceAccess) async throws {
        for _ in 0..<400 where !access.stoppedURLPaths.contains(directory.path) {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(access.stoppedURLPaths.contains(directory.path))
    }
}
