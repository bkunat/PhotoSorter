//
//  PhotoSorter
//

import Foundation

enum PhotoStatus: Equatable {
    case uncategorized
    case categorized(Category.ID)

    var assignedCategoryID: Category.ID? {
        guard case let .categorized(categoryID) = self else { return nil }
        return categoryID
    }

    var isUncategorized: Bool {
        if case .uncategorized = self {
            return true
        }

        return false
    }
}

struct PhotoItem: Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    var currentURL: URL
    let filename: String
    var status: PhotoStatus

    init(
        id: UUID = UUID(),
        originalURL: URL,
        currentURL: URL? = nil,
        filename: String? = nil,
        status: PhotoStatus = .uncategorized
    ) {
        self.id = id
        self.originalURL = originalURL
        self.currentURL = currentURL ?? originalURL
        self.filename = filename ?? originalURL.lastPathComponent
        self.status = status
    }
}
