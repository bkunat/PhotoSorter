//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselContainerView: NSView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let scrollView = NSScrollView()
    private let collectionView = NSCollectionView()
    private let previewLoader: PhotoCarouselPreviewLoader
    private var photos: [PhotoItem] = []
    private var categoriesByID: [Category.ID: Category] = [:]
    private var currentPhotoIndex: Int?
    private var needsSelectionScroll = false
    private var isUpdatingDocumentFrame = false

    var onSelectPhoto: ((Int) -> Void)?

    init(previewLoader: PhotoCarouselPreviewLoader) {
        self.previewLoader = previewLoader
        super.init(frame: .zero)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none

        collectionView.collectionViewLayout = PhotoCarouselFlowLayout()
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCarouselItem.self, forItemWithIdentifier: PhotoCarouselItem.reuseIdentifier)
        scrollView.documentView = collectionView
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateDocumentFrame()
        guard needsSelectionScroll, bounds.width > 0 else { return }
        needsSelectionScroll = false
        scrollToSelection()
    }

    func update(photos: [PhotoItem], categoriesByID: [Category.ID: Category], currentPhotoIndex: Int?) {
        let identityChanged = self.photos.map(\.id) != photos.map(\.id)
        let metadataChanged = self.photos != photos || self.categoriesByID != categoriesByID
        let selectionChanged = self.currentPhotoIndex != currentPhotoIndex
        self.photos = photos
        self.categoriesByID = categoriesByID
        self.currentPhotoIndex = currentPhotoIndex
        previewLoader.updatePhotos(photos)

        if identityChanged {
            collectionView.reloadData()
        } else if metadataChanged {
            for item in collectionView.visibleItems() {
                guard let item = item as? PhotoCarouselItem,
                      let indexPath = collectionView.indexPath(for: item) else { continue }
                configure(item, at: indexPath.item)
            }
        }

        let selection = currentPhotoIndex.map { Set([IndexPath(item: $0, section: 0)]) } ?? []
        if collectionView.selectionIndexPaths != selection {
            collectionView.selectionIndexPaths = selection
        }
        if selectionChanged || identityChanged {
            needsSelectionScroll = true
            needsLayout = true
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: PhotoCarouselItem.reuseIdentifier, for: indexPath)
        if let item = item as? PhotoCarouselItem {
            configure(item, at: indexPath.item)
        }
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let index = indexPaths.first?.item, index != currentPhotoIndex else { return }
        onSelectPhoto?(index)
    }

    private func configure(_ item: PhotoCarouselItem, at index: Int) {
        guard photos.indices.contains(index) else { return }
        let photo = photos[index]
        item.configure(
            photo: photo,
            positionText: "Photo \(index + 1) of \(photos.count)",
            category: photo.status.assignedCategoryID.flatMap { categoriesByID[$0] },
            previewLoader: previewLoader
        )
        item.onSelect = { [weak self] in
            guard let self, self.photos.indices.contains(index), self.photos[index].id == photo.id else { return }
            self.onSelectPhoto?(index)
        }
    }

    private func updateDocumentFrame() {
        guard !isUpdatingDocumentFrame else { return }
        isUpdatingDocumentFrame = true
        defer { isUpdatingDocumentFrame = false }
        let viewportSize = scrollView.contentSize
        if collectionView.frame.height != viewportSize.height {
            collectionView.setFrameSize(NSSize(width: max(viewportSize.width, collectionView.frame.width), height: viewportSize.height))
            collectionView.collectionViewLayout?.invalidateLayout()
        }
        let contentWidth = collectionView.collectionViewLayout?.collectionViewContentSize.width ?? 0
        let width = max(viewportSize.width, contentWidth)
        if collectionView.frame.width != width {
            collectionView.setFrameSize(NSSize(width: width, height: viewportSize.height))
        }
    }

    private func scrollToSelection() {
        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else { return }
        collectionView.layoutSubtreeIfNeeded()
        // Immediate navigation also respects Reduce Motion and keeps rapid key presses predictable.
        collectionView.scrollToItems(
            at: [IndexPath(item: currentPhotoIndex, section: 0)],
            scrollPosition: .centeredHorizontally
        )
    }
}
