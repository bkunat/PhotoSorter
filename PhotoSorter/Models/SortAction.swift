//
//  PhotoSorter
//

import Foundation

struct SortAction: Equatable {
    let photoID: PhotoItem.ID
    let sourceURL: URL
    let destinationURL: URL
    let previousStatus: PhotoStatus
    let nextStatus: PhotoStatus

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
