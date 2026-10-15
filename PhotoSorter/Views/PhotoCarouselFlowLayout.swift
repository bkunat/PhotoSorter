//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselFlowLayout: NSCollectionViewFlowLayout {
    override init() {
        super.init()
        scrollDirection = .horizontal
        itemSize = NSSize(width: 94, height: 94)
        minimumLineSpacing = 10
        minimumInteritemSpacing = 10
        sectionInset = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
