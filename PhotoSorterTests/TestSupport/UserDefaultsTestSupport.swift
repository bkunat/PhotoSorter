//
//  PhotoSorter
//

import XCTest

extension XCTestCase {
    func makeTestUserDefaults() -> UserDefaults {
        let suiteName = "PhotoSorterTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        addTeardownBlock {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        return userDefaults
    }
}
