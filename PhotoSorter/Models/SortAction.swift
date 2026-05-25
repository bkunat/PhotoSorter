//
//  PhotoSorter
//

import Foundation

struct SortAction: Equatable {
    let photoID: PhotoItem.ID
    let categoryID: Category.ID
    let sourceURL: URL
    let destinationURL: URL
}
