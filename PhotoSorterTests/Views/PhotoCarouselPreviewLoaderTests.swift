//
//  PhotoSorter
//

import AppKit
import XCTest
@testable import PhotoSorter

@MainActor
final class PhotoCarouselPreviewLoaderTests: XCTestCase {
    func testConcurrentRequestsForSamePhotoDecodeOnceAndCompleteBoth() async {
        let started = expectation(description: "Decode started")
        let completed = expectation(description: "Both callers completed")
        completed.expectedFulfillmentCount = 2
        let gate = DispatchSemaphore(value: 0)
        let probe = DecodeProbe()
        let loader = PhotoCarouselPreviewLoader { url in
            probe.record(url)
            started.fulfill()
            _ = gate.wait(timeout: .now() + 5)
            return Self.makeImage()
        }
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"))
        for _ in 0..<2 {
            loader.loadPreview(for: photo) { image in
                XCTAssertNotNil(image)
                completed.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: 2)
        gate.signal()
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(probe.urls.count, 1)
    }

    func testMovedPhotoReusesDecodedPreview() async {
        let loaded = expectation(description: "Original preview loaded")
        let probe = DecodeProbe()
        let loader = PhotoCarouselPreviewLoader { url in
            probe.record(url)
            return Self.makeImage()
        }
        var photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"))
        loader.updatePhotos([photo])
        loader.loadPreview(for: photo) { image in
            XCTAssertNotNil(image)
            loaded.fulfill()
        }
        await fulfillment(of: [loaded], timeout: 2)
        let originalImage = loader.cachedPreview(for: photo)

        photo.currentURL = URL(fileURLWithPath: "/Category/photo.jpg")
        photo.status = .categorized(UUID())
        loader.updatePhotos([photo])
        let reused = expectation(description: "Moved preview reused")
        loader.loadPreview(for: photo) { image in
            XCTAssertTrue(image === originalImage)
            reused.fulfill()
        }
        await fulfillment(of: [reused], timeout: 2)
        XCTAssertEqual(probe.urls.count, 1)
    }

    func testFailedDecodeAtOldPathRetriesMovedPathForAllCallers() async {
        let started = expectation(description: "Old path decode started")
        let completed = expectation(description: "Both callers received moved image")
        completed.expectedFulfillmentCount = 2
        let gate = DispatchSemaphore(value: 0)
        let oldURL = URL(fileURLWithPath: "/photo.jpg")
        let newURL = URL(fileURLWithPath: "/Category/photo.jpg")
        let probe = DecodeProbe()
        let loader = PhotoCarouselPreviewLoader { url in
            probe.record(url)
            if url == oldURL {
                started.fulfill()
                _ = gate.wait(timeout: .now() + 5)
                return nil
            }
            return Self.makeImage()
        }
        var photo = PhotoItem(originalURL: oldURL)
        loader.updatePhotos([photo])
        loader.loadPreview(for: photo) { image in
            XCTAssertNotNil(image)
            completed.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        photo.currentURL = newURL
        loader.updatePhotos([photo])
        loader.loadPreview(for: photo) { image in
            XCTAssertNotNil(image)
            completed.fulfill()
        }
        gate.signal()
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(probe.urls, [oldURL, newURL])
    }

    func testDecodeFailureCompletesAndCanBeRetried() async {
        let probe = DecodeProbe()
        let loader = PhotoCarouselPreviewLoader { url in
            probe.record(url)
            return nil
        }
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/broken.jpg"))
        for _ in 0..<2 {
            let completed = expectation(description: "Failure delivered")
            loader.loadPreview(for: photo) { image in
                XCTAssertNil(image)
                completed.fulfill()
            }
            await fulfillment(of: [completed], timeout: 2)
        }
        XCTAssertNil(loader.cachedPreview(for: photo))
        XCTAssertEqual(probe.urls.count, 2)
    }

    func testDecodeConcurrencyIsBounded() async {
        let started = expectation(description: "Two decodes started")
        started.expectedFulfillmentCount = 2
        let completed = expectation(description: "All previews completed")
        completed.expectedFulfillmentCount = 6
        let gate = DispatchSemaphore(value: 0)
        let probe = DecodeProbe()
        let loader = PhotoCarouselPreviewLoader(maximumConcurrentDecodes: 2) { url in
            let count = probe.begin(url)
            if count <= 2 { started.fulfill() }
            _ = gate.wait(timeout: .now() + 5)
            probe.end()
            return Self.makeImage()
        }
        for index in 0..<6 {
            loader.loadPreview(for: PhotoItem(originalURL: URL(fileURLWithPath: "/\(index).jpg"))) { image in
                XCTAssertNotNil(image)
                completed.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(probe.urls.count, 2)
        for _ in 0..<6 { gate.signal() }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertLessThanOrEqual(probe.maximumActiveCount, 2)
    }

    func testNewFocusedPhotoRunsBeforeQueuedFormerDisplayRequests() async {
        let started = expectation(description: "First decode blocks queue")
        let completed = expectation(description: "Display callers completed")
        completed.expectedFulfillmentCount = 3
        let gate = DispatchSemaphore(value: 0)
        let probe = DecodeProbe()
        let photos = (0..<15).map { PhotoItem(originalURL: URL(fileURLWithPath: "/\($0).jpg")) }
        let loader = PhotoCarouselPreviewLoader(maximumConcurrentDecodes: 1) { url in
            probe.record(url)
            if url.lastPathComponent == "0.jpg" {
                started.fulfill()
                _ = gate.wait(timeout: .now() + 5)
            }
            return Self.makeImage()
        }
        loader.updatePhotos(photos)
        loader.loadPreview(for: photos[0]) { _ in }
        await fulfillment(of: [started], timeout: 2)
        for index in [1, 2] {
            loader.loadPreview(for: photos[index]) { image in
                XCTAssertNotNil(image)
                completed.fulfill()
            }
        }
        loader.preload(photos: photos, around: 10)
        loader.loadPreview(for: photos[10]) { image in
            XCTAssertNotNil(image)
            completed.fulfill()
        }
        gate.signal()
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(Array(probe.urls.prefix(2)), [photos[0].currentURL, photos[10].currentURL])
    }

    func testMovingPrefetchWindowCancelsObsoleteQueuedDecodes() async {
        let started = expectation(description: "First prefetch started")
        let wantedDecoded = expectation(description: "New neighborhood decoded")
        wantedDecoded.expectedFulfillmentCount = 3
        let obsoleteDecoded = expectation(description: "Obsolete queued prefetch must not decode")
        obsoleteDecoded.isInverted = true
        let gate = DispatchSemaphore(value: 0)
        let photos = (0..<10).map { PhotoItem(originalURL: URL(fileURLWithPath: "/\($0).jpg")) }
        let loader = PhotoCarouselPreviewLoader(maximumConcurrentDecodes: 1) { url in
            if url.lastPathComponent == "0.jpg" {
                started.fulfill()
                _ = gate.wait(timeout: .now() + 5)
            } else if ["7.jpg", "8.jpg", "9.jpg"].contains(url.lastPathComponent) {
                wantedDecoded.fulfill()
            } else {
                obsoleteDecoded.fulfill()
            }
            return Self.makeImage()
        }
        loader.updatePhotos(photos)
        loader.preload(photos: photos, around: 0)
        await fulfillment(of: [started], timeout: 2)
        loader.preload(photos: photos, around: 9)
        gate.signal()
        await fulfillment(of: [wantedDecoded], timeout: 2)
        await fulfillment(of: [obsoleteDecoded], timeout: 0.1)
    }

    func testReplacingSessionCancelsOldCallbacksAndDiscardsOldResult() async {
        let started = expectation(description: "Old session decode started")
        let cancelled = expectation(description: "Old caller released")
        let loaded = expectation(description: "New session loaded")
        let gate = DispatchSemaphore(value: 0)
        let oldPhoto = PhotoItem(originalURL: URL(fileURLWithPath: "/old.jpg"))
        let newPhoto = PhotoItem(originalURL: URL(fileURLWithPath: "/new.jpg"))
        let loader = PhotoCarouselPreviewLoader(maximumConcurrentDecodes: 1) { url in
            if url.lastPathComponent == "old.jpg" {
                started.fulfill()
                _ = gate.wait(timeout: .now() + 5)
            }
            return Self.makeImage()
        }
        loader.updatePhotos([oldPhoto])
        loader.loadPreview(for: oldPhoto) { image in
            XCTAssertNil(image)
            cancelled.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        loader.updatePhotos([newPhoto])
        loader.loadPreview(for: newPhoto) { image in
            XCTAssertNotNil(image)
            loaded.fulfill()
        }
        gate.signal()
        await fulfillment(of: [cancelled, loaded], timeout: 2)
        XCTAssertNil(loader.cachedPreview(for: oldPhoto))
        XCTAssertNotNil(loader.cachedPreview(for: newPhoto))
    }

    nonisolated private static func makeImage() -> CGImage? {
        CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage()
    }
}

private final class DecodeProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedURLs: [URL] = []
    private var activeCount = 0
    private var maximumCount = 0

    var urls: [URL] { lock.withLock { recordedURLs } }
    var maximumActiveCount: Int { lock.withLock { maximumCount } }

    func record(_ url: URL) {
        lock.withLock { recordedURLs.append(url) }
    }

    func begin(_ url: URL) -> Int {
        lock.withLock {
            recordedURLs.append(url)
            activeCount += 1
            maximumCount = max(maximumCount, activeCount)
            return recordedURLs.count
        }
    }

    func end() {
        lock.withLock { activeCount -= 1 }
    }
}
