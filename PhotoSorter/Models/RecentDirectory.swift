//
//  PhotoSorter
//

import Foundation

struct RecentDirectory: Codable, Hashable, Identifiable {
    let displayName: String
    let path: String
    let bookmarkData: Data
    let lastOpenedAt: Date

    var id: String { path }
}
