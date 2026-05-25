//
//  PhotoSorter
//

import Foundation
@testable import PhotoSorter

final class FakeSecurityScopedResourceAccess: SecurityScopedResourceAccess {
    private let lock = NSLock()
    private let startResult: Bool
    nonisolated(unsafe) private var startedURLs: [URL] = []
    nonisolated(unsafe) private var stoppedURLs: [URL] = []

    init(startResult: Bool = false) {
        self.startResult = startResult
    }

    var startedURLPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return startedURLs.map(\.path)
    }

    var stoppedURLPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stoppedURLs.map(\.path)
    }

    nonisolated func startAccessing(_ url: URL) -> Bool {
        lock.lock()
        startedURLs.append(url)
        lock.unlock()
        return startResult
    }

    nonisolated func stopAccessing(_ url: URL) {
        lock.lock()
        stoppedURLs.append(url)
        lock.unlock()
    }
}
