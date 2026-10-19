//
//  PhotoSorter
//

enum PhotoContextAction: Equatable {
    case edit
    case categorize(Category.ID?)
    case delete
    case copy
    case quickLook
    case showInFinder
}
