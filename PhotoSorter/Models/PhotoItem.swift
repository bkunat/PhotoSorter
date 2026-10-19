//
//  PhotoSorter
//

import Foundation

nonisolated enum PhotoStatus: Equatable, Sendable {
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

nonisolated struct PhotoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let originalURL: URL
    var currentURL: URL
    let filename: String
    var status: PhotoStatus
    var contentRevision = UUID()

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
