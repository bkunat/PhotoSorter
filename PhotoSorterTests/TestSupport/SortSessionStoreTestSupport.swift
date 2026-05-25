//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

@MainActor
extension XCTestCase {
    func makeStore(
        userDefaults: UserDefaults? = nil,
        securityScopedResourceAccess: SecurityScopedResourceAccess? = nil
    ) -> SortSessionStore {
        SortSessionStore(
            userDefaults: userDefaults ?? makeTestUserDefaults(),
            securityScopedResourceAccess: securityScopedResourceAccess ?? FakeSecurityScopedResourceAccess(startResult: false)
        )
    }
}
