//
//  PhotoSorter
//

import SwiftUI

struct PhotoCarouselView: NSViewRepresentable {
    let photos: [PhotoItem]
    let categoriesByID: [Category.ID: Category]
    let currentPhotoIndex: Int?
    let onSelectPhoto: (Int) -> Void

    func makeNSView(context: Context) -> PhotoCarouselContainerView {
        let view = PhotoCarouselContainerView()
        view.onSelectPhoto = onSelectPhoto
        view.update(
            photos: photos,
            categoriesByID: categoriesByID,
            currentPhotoIndex: currentPhotoIndex,
            animated: false
        )
        return view
    }

    func updateNSView(_ nsView: PhotoCarouselContainerView, context: Context) {
        nsView.onSelectPhoto = onSelectPhoto
        nsView.update(
            photos: photos,
            categoriesByID: categoriesByID,
            currentPhotoIndex: currentPhotoIndex,
            animated: true
        )
    }
}
