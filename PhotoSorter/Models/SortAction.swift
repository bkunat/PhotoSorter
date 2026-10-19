//
//  PhotoSorter
//

import Foundation

struct SortAction: Equatable {
    let photoID: PhotoItem.ID
    var sourceURL: URL
    var destinationURL: URL
    let previousStatus: PhotoStatus
    let nextStatus: PhotoStatus
    var kind: Kind = .move

    enum Kind: Equatable {
        case move
        case edit(backupURL: URL, editedDigest: Data)
        case deletion(photo: PhotoItem, index: Int)
    }

    var categoryID: Category.ID? {
        nextStatus.assignedCategoryID ?? previousStatus.assignedCategoryID
    }

    init(photoID: PhotoItem.ID, sourceURL: URL, destinationURL: URL, previousStatus: PhotoStatus, nextStatus: PhotoStatus) {
        self.photoID = photoID
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.previousStatus = previousStatus
        self.nextStatus = nextStatus
    }

    init(photoID: PhotoItem.ID, categoryID: Category.ID, sourceURL: URL, destinationURL: URL) {
        self.init(
            photoID: photoID,
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            previousStatus: .uncategorized,
            nextStatus: .categorized(categoryID)
        )
    }
}
