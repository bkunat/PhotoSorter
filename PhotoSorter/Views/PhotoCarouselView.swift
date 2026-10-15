//
//  PhotoSorter
//

import SwiftUI

struct PhotoCarouselView: View {
    let photos: [PhotoItem]
    let categoriesByID: [Category.ID: Category]
    let currentPhotoIndex: Int?
    let onSelectPhoto: (Int) -> Void

    @State private var previewLoader = PhotoCarouselPreviewLoader()

    var body: some View {
        VStack(spacing: 12) {
            if let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) {
                let photo = photos[currentPhotoIndex]
                PhotoPreviewView(
                    photo: photo,
                    position: "Photo \(currentPhotoIndex + 1) of \(photos.count)",
                    categoryName: photo.status.assignedCategoryID.flatMap { categoriesByID[$0]?.name },
                    previewLoader: previewLoader
                )
            }

            PhotoFilmstripView(
                photos: photos,
                categoriesByID: categoriesByID,
                currentPhotoIndex: currentPhotoIndex,
                previewLoader: previewLoader,
                onSelectPhoto: onSelectPhoto
            )
            .frame(height: 112)
            .accessibilityLabel("Photo filmstrip")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .onChange(of: photos, initial: true) { _, photos in
            previewLoader.updatePhotos(photos)
        }
        .onChange(of: currentPhotoIndex, initial: true) { _, index in
            if let index {
                previewLoader.preload(photos: photos, around: index)
            }
        }
    }
}

private struct PhotoPreviewView: View {
    let photo: PhotoItem
    let position: String
    let categoryName: String?
    let previewLoader: PhotoCarouselPreviewLoader

    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var requestID = UUID()
    @State private var displayedPhotoID: PhotoItem.ID?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .accessibilityLabel("\(photo.filename), \(categoryName ?? "Unsorted"), \(position)")
                } else if isLoading {
                    ProgressView("Loading preview…")
                } else {
                    ContentUnavailableView {
                        Label("Preview unavailable", systemImage: "photo.badge.exclamationmark")
                    } description: {
                        Text("Try opening this photo with Quick Look.")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text(photo.filename)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(photo.currentURL.path)
                Spacer(minLength: 8)
                Label(categoryName ?? "Unsorted", systemImage: categoryName == nil ? "circle" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onChange(of: photo, initial: true) { _, photo in
            let request = UUID()
            requestID = request
            if displayedPhotoID != photo.id {
                image = nil
            }
            displayedPhotoID = photo.id
            isLoading = true
            previewLoader.loadPreview(for: photo) { preview in
                guard requestID == request else { return }
                image = preview
                isLoading = false
            }
        }
        .onDisappear { requestID = UUID() }
    }
}

private struct PhotoFilmstripView: NSViewRepresentable {
    let photos: [PhotoItem]
    let categoriesByID: [Category.ID: Category]
    let currentPhotoIndex: Int?
    let previewLoader: PhotoCarouselPreviewLoader
    let onSelectPhoto: (Int) -> Void

    func makeNSView(context: Context) -> PhotoCarouselContainerView {
        PhotoCarouselContainerView(previewLoader: previewLoader)
    }

    func updateNSView(_ nsView: PhotoCarouselContainerView, context: Context) {
        nsView.onSelectPhoto = onSelectPhoto
        nsView.update(photos: photos, categoriesByID: categoriesByID, currentPhotoIndex: currentPhotoIndex)
    }
}
