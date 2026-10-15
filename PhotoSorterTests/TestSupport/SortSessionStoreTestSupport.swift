//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
extension XCTestCase {
    func makeStore(
        userDefaults: UserDefaults? = nil,
        securityScopedResourceAccess: SecurityScopedResourceAccess? = nil,
        scanner: (any SessionScanning)? = nil
    ) -> SortSessionStore {
        SortSessionStore(
            userDefaults: userDefaults ?? makeTestUserDefaults(),
            securityScopedResourceAccess: securityScopedResourceAccess ?? FakeSecurityScopedResourceAccess(startResult: false),
            scanner: scanner
        )
    }
    func waitForLoading(_ store: SortSessionStore, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<400 where store.isLoading {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertFalse(store.isLoading, "Folder load did not finish", file: file, line: line)
    }
}
