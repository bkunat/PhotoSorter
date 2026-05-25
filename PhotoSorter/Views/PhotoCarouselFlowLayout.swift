//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselFlowLayout: NSCollectionViewFlowLayout {
    private let minimumCardWidth: CGFloat = 250
    private let maximumCardWidth: CGFloat = 380
    private let maximumFocusScale: CGFloat = 1.4
    private let minimumCardScale: CGFloat = 0.68

    override func prepare() {
        super.prepare()

        guard let collectionView else { return }

        scrollDirection = .horizontal
        minimumLineSpacing = 42
        minimumInteritemSpacing = 42

        let viewportBounds = collectionView.enclosingScrollView?.contentView.bounds ?? collectionView.bounds
        let availableBounds = viewportBounds.insetBy(dx: 56, dy: 24)
        let baseHeight = max(320, min((availableBounds.height - 12) / maximumFocusScale, 500))
        let baseWidth = min(max(availableBounds.width * 0.32, minimumCardWidth), maximumCardWidth)
        let focusedWidth = baseWidth * maximumFocusScale
        let focusedHeight = baseHeight * maximumFocusScale

        itemSize = NSSize(width: baseWidth, height: baseHeight)
        sectionInset = NSEdgeInsets(
            top: max((viewportBounds.height - focusedHeight) / 2, 18),
            left: max((viewportBounds.width - focusedWidth) / 2, 28),
            bottom: max((viewportBounds.height - focusedHeight) / 2, 18),
            right: max((viewportBounds.width - focusedWidth) / 2, 28)
        )
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        true
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let attributes = super.layoutAttributesForElements(in: rect)

        return attributes.compactMap { attribute in
            guard let copy = attribute.copy() as? NSCollectionViewLayoutAttributes else {
                return nil
            }

            return styledAttributes(from: copy)
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath)?.copy() as? NSCollectionViewLayoutAttributes else {
            return nil
        }

        return styledAttributes(from: attributes)
    }

    private func styledAttributes(from attributes: NSCollectionViewLayoutAttributes) -> NSCollectionViewLayoutAttributes {
        guard let collectionView else { return attributes }

        let viewportCenterX = collectionView.enclosingScrollView?.contentView.bounds.midX ?? collectionView.bounds.midX
        let distance = abs(attributes.frame.midX - viewportCenterX)
        let normalizationDistance = max(itemSize.width + minimumLineSpacing, 1)
        let normalizedDistance = min(distance / normalizationDistance, 2)

        let scale = interpolatedValue(
            from: maximumFocusScale,
            to: minimumCardScale,
            progress: min(normalizedDistance, 1)
        )
        let alpha = interpolatedValue(
            from: 1,
            to: 0.5,
            progress: min(normalizedDistance / 1.4, 1)
        )
        let yOffset = interpolatedValue(
            from: 0,
            to: 26,
            progress: min(normalizedDistance, 1)
        )

        let scaledWidth = itemSize.width * scale
        let scaledHeight = itemSize.height * scale
        let midX = attributes.frame.midX
        let midY = collectionView.visibleRect.midY - yOffset

        attributes.frame = NSRect(
            x: midX - (scaledWidth / 2),
            y: midY - (scaledHeight / 2),
            width: scaledWidth,
            height: scaledHeight
        )
        attributes.alpha = alpha
        attributes.zIndex = Int((2 - normalizedDistance) * 100)

        return attributes
    }

    private func interpolatedValue(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + ((end - start) * progress)
    }
}
