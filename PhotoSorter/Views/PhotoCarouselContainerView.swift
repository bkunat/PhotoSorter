//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselContainerView: NSView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let scrollView = NSScrollView()
    private let collectionView = NSCollectionView()
    private let flowLayout = PhotoCarouselFlowLayout()
    private let previewLoader = PhotoCarouselPreviewLoader()

    private var photos: [PhotoItem] = []
    private var categoriesByID: [Category.ID: Category] = [:]
    private var currentPhotoIndex: Int?
    private var lastScheduledPreloadRange: ClosedRange<Int>?
    private var pendingViewportSelectionIndex: Int?
    private var isProgrammaticSelectionUpdate = false
    private var isProgrammaticScrollAnimation = false
    private var isPreservingFocusAfterResize = false
    private var isSyncingCollectionViewFrame = false
    private var lastViewportSize: NSSize = .zero
    private var needsInitialCentering = false
    private var snapWorkItem: DispatchWorkItem?

    var onSelectPhoto: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureViewHierarchy()
        observeScrollBounds()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()

        let viewportSizeChanged = updateViewportSizeTracking()
        flowLayout.invalidateLayout()
        syncCollectionViewFrame()

        if viewportSizeChanged {
            preserveFocusedPhotoAfterViewportResize()
            return
        }

        guard needsInitialCentering, let currentPhotoIndex else { return }
        needsInitialCentering = false
        centerPhoto(at: currentPhotoIndex, animated: false)
    }

    func update(
        photos: [PhotoItem],
        categoriesByID: [Category.ID: Category],
        currentPhotoIndex: Int?,
        animated: Bool
    ) {
        let photosChanged = self.photos != photos
        let categoriesChanged = self.categoriesByID != categoriesByID
        let previousCurrentPhotoIndex = self.currentPhotoIndex
        let selectionCameFromViewport = pendingViewportSelectionIndex == currentPhotoIndex

        self.photos = photos
        self.categoriesByID = categoriesByID
        self.currentPhotoIndex = currentPhotoIndex

        if photosChanged {
            lastScheduledPreloadRange = nil
        }

        if selectionCameFromViewport {
            pendingViewportSelectionIndex = nil
        }

        if photosChanged || categoriesChanged {
            collectionView.reloadData()
            flowLayout.invalidateLayout()
        }

        syncCollectionViewFrame()

        updateSelectedIndexPaths()
        schedulePreviewPreloadIfNeeded(around: currentPhotoIndex)

        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else {
            return
        }

        let shouldCenterPhoto = photosChanged || (
            previousCurrentPhotoIndex != currentPhotoIndex &&
            selectionCameFromViewport == false
        )

        guard shouldCenterPhoto else { return }

        if bounds.width > 0, window != nil {
            centerPhoto(at: currentPhotoIndex, animated: animated)
        } else {
            needsInitialCentering = true
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: PhotoCarouselItem.reuseIdentifier,
            for: indexPath
        )

        guard
            let photoItem = item as? PhotoCarouselItem,
            photos.indices.contains(indexPath.item)
        else {
            return item
        }

        photoItem.configure(
            photo: photos[indexPath.item],
            positionText: "Photo \(indexPath.item + 1) of \(photos.count)",
            category: photos[indexPath.item].status.assignedCategoryID.flatMap { categoriesByID[$0] },
            previewLoader: previewLoader
        )

        return photoItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard
            isProgrammaticSelectionUpdate == false,
            let indexPath = indexPaths.sorted().first
        else {
            return
        }

        selectPhotoFromViewport(at: indexPath.item)
        centerPhoto(at: indexPath.item, animated: true)
    }

    private func configureViewHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        collectionView.frame = bounds
        collectionView.autoresizingMask = [.height]
        collectionView.collectionViewLayout = flowLayout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.delegate = self
        collectionView.dataSource = self
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

    private func observeScrollBounds() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc
    private func handleScrollBoundsDidChange() {
        // Scrolling should restyle visible items only. Resizing the document view from
        // inside the clip-view notification re-enters AppKit layout and can recurse.
        let viewportSizeChanged = updateViewportSizeTracking()
        flowLayout.invalidateLayout()

        guard isProgrammaticScrollAnimation == false, isPreservingFocusAfterResize == false else { return }

        if viewportSizeChanged {
            preserveFocusedPhotoAfterViewportResize()
            return
        }

        updateFocusedPhotoFromViewport()
        scheduleSnapToNearestPhoto()
    }

    private func updateSelectedIndexPaths() {
        isProgrammaticSelectionUpdate = true

        defer {
            isProgrammaticSelectionUpdate = false
        }

        if let currentPhotoIndex {
            collectionView.selectionIndexPaths = Set([IndexPath(item: currentPhotoIndex, section: 0)])
        } else {
            collectionView.selectionIndexPaths = []
        }
    }

    private func updateFocusedPhotoFromViewport() {
        guard let nearestIndex = nearestIndexToViewportCenter() else { return }
        updateSelectedIndexPathsIfNeeded(for: nearestIndex)

        guard nearestIndex != currentPhotoIndex else { return }
        selectPhotoFromViewport(at: nearestIndex)
    }

    private func updateSelectedIndexPathsIfNeeded(for index: Int) {
        let targetIndexPaths = Set([IndexPath(item: index, section: 0)])

        guard collectionView.selectionIndexPaths != targetIndexPaths else {
            return
        }

        isProgrammaticSelectionUpdate = true
        collectionView.selectionIndexPaths = targetIndexPaths
        isProgrammaticSelectionUpdate = false
    }

    private func scheduleSnapToNearestPhoto() {
        snapWorkItem?.cancel()

        guard let nearestIndex = nearestIndexToViewportCenter() else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.centerPhoto(at: nearestIndex, animated: true)
        }

        snapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    private func updateViewportSizeTracking() -> Bool {
        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return false }

        let sizeChanged = abs(viewportSize.width - lastViewportSize.width) >= 0.5 ||
            abs(viewportSize.height - lastViewportSize.height) >= 0.5

        lastViewportSize = viewportSize
        return sizeChanged
    }

    private func preserveFocusedPhotoAfterViewportResize() {
        guard isPreservingFocusAfterResize == false else { return }
        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else { return }

        isPreservingFocusAfterResize = true
        defer { isPreservingFocusAfterResize = false }

        updateSelectedIndexPaths()
        schedulePreviewPreloadIfNeeded(around: currentPhotoIndex)
        centerPhoto(
            at: currentPhotoIndex,
            animated: false,
            updatesFocusedPhotoFromViewport: false
        )
    }

    private func nearestIndexToViewportCenter() -> Int? {
        guard photos.isEmpty == false else { return nil }

        let viewportCenterX = scrollView.contentView.bounds.midX
        let extendedRect = scrollView.contentView.bounds.insetBy(dx: -bounds.width, dy: 0)
        let attributes = flowLayout.layoutAttributesForElements(in: extendedRect)

        let nearestAttribute = attributes.min { lhs, rhs in
            abs(lhs.frame.midX - viewportCenterX) < abs(rhs.frame.midX - viewportCenterX)
        }

        return nearestAttribute?.indexPath?.item
    }

    private func selectPhotoFromViewport(at index: Int) {
        guard photos.indices.contains(index) else { return }
        guard pendingViewportSelectionIndex != index else { return }

        AppLogger.debug(
            "Carousel focused photo \(index + 1) of \(photos.count): \(photos[index].filename)",
            category: .ui
        )
        schedulePreviewPreloadIfNeeded(around: index)
        pendingViewportSelectionIndex = index
        onSelectPhoto?(index)
    }

    private func schedulePreviewPreloadIfNeeded(around currentIndex: Int?) {
        guard let currentIndex, photos.indices.contains(currentIndex) else { return }

        let preloadRange = preloadRange(for: currentIndex)
        guard lastScheduledPreloadRange != preloadRange else { return }

        lastScheduledPreloadRange = preloadRange
        previewLoader.preload(photos: photos, around: currentIndex)
    }

    private func preloadRange(for currentIndex: Int, previousCount: Int = 6, nextCount: Int = 10) -> ClosedRange<Int> {
        let lowerBound = max(currentIndex - previousCount, photos.startIndex)
        let upperBound = min(currentIndex + nextCount, photos.index(before: photos.endIndex))
        return lowerBound...upperBound
    }

    private func centerPhoto(
        at index: Int,
        animated: Bool,
        updatesFocusedPhotoFromViewport: Bool = true
    ) {
        guard photos.indices.contains(index) else { return }

        syncCollectionViewFrame()
        collectionView.layoutSubtreeIfNeeded()
        guard let attributes = flowLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)) else {
            return
        }

        let viewportWidth = scrollView.contentView.bounds.width
        let documentWidth = collectionView.collectionViewLayout?.collectionViewContentSize.width ?? collectionView.bounds.width
        let targetOffsetX = max(
            0,
            min(attributes.frame.midX - (viewportWidth / 2), max(documentWidth - viewportWidth, 0))
        )

        let targetOrigin = NSPoint(x: targetOffsetX, y: 0)
        snapWorkItem?.cancel()

        if animated {
            isProgrammaticScrollAnimation = true

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.scrollView.contentView.animator().setBoundsOrigin(targetOrigin)
            } completionHandler: {
                self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
                self.isProgrammaticScrollAnimation = false
                if updatesFocusedPhotoFromViewport {
                    self.updateFocusedPhotoFromViewport()
                }
            }
        } else {
            scrollView.contentView.setBoundsOrigin(targetOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            if updatesFocusedPhotoFromViewport {
                updateFocusedPhotoFromViewport()
            }
        }
    }

    private func syncCollectionViewFrame() {
        guard isSyncingCollectionViewFrame == false else { return }

        let viewportSize = scrollView.contentView.bounds.size
        let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize ?? .zero
        let targetFrame = NSRect(
            origin: .zero,
            size: NSSize(
                width: max(contentSize.width, viewportSize.width),
                height: max(contentSize.height, viewportSize.height)
            )
        )

        guard collectionView.frame != targetFrame else { return }
        isSyncingCollectionViewFrame = true
        defer { isSyncingCollectionViewFrame = false }
        collectionView.frame = targetFrame
    }
}
