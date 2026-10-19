//
//  PhotoSorter
//

import AppKit
import ImageIO

@MainActor
final class PhotoCarouselPreviewLoader {
    private struct Request {
        var url: URL
        let contentRevision: UUID
        let token: UUID
        let operation: BlockOperation
        var completions: [(NSImage?) -> Void]
    }

    private let cache = NSCache<NSUUID, NSImage>()
    private let decodeQueue = OperationQueue()
    private let decode: @Sendable (URL) -> CGImage?
    private var requests: [PhotoItem.ID: Request] = [:]
    private var photoIDs: Set<PhotoItem.ID> = []

    init(
        maximumConcurrentDecodes: Int = 2,
        decode: @escaping @Sendable (URL) -> CGImage? = PhotoCarouselPreviewLoader.decodeImage
    ) {
        self.decode = decode
        decodeQueue.name = "PhotoSorter.PhotoCarouselPreviewLoader.Decode"
        decodeQueue.qualityOfService = .userInitiated
        decodeQueue.maxConcurrentOperationCount = max(1, maximumConcurrentDecodes)
        cache.totalCostLimit = 96 * 1_024 * 1_024
    }

    deinit {
        decodeQueue.cancelAllOperations()
    }

    func cachedPreview(for photo: PhotoItem) -> NSImage? {
        cache.object(forKey: photo.contentRevision as NSUUID)
    }

    func updatePhotos(_ photos: [PhotoItem]) {
        let updatedIDs = Set(photos.map(\.id))
        if updatedIDs != photoIDs {
            for id in requests.keys where !updatedIDs.contains(id) {
                cancelRequest(for: id)
            }
            if !photoIDs.isEmpty, photoIDs.isDisjoint(with: updatedIDs) {
                cache.removeAllObjects()
            }
            photoIDs = updatedIDs
        }
        for photo in photos {
            if let request = requests[photo.id], request.contentRevision != photo.contentRevision {
                cancelRequest(for: photo.id)
            } else {
                requests[photo.id]?.url = photo.currentURL
            }
        }
    }

    func loadPreview(
        for photo: PhotoItem,
        priority: Operation.QueuePriority = .veryHigh,
        completion: @escaping (NSImage?) -> Void
    ) {
        if let request = requests[photo.id], request.contentRevision != photo.contentRevision {
            cancelRequest(for: photo.id)
        }
        if let image = cachedPreview(for: photo) {
            completion(image)
            return
        }
        if var request = requests[photo.id] {
            request.url = photo.currentURL
            request.completions.append(completion)
            if request.operation.queuePriority.rawValue < priority.rawValue {
                request.operation.queuePriority = priority
            }
            requests[photo.id] = request
            return
        }
        enqueue(id: photo.id, url: photo.currentURL, contentRevision: photo.contentRevision, completions: [completion], priority: priority)
    }

    func preload(photos: [PhotoItem], around currentIndex: Int) {
        updatePhotos(photos)
        guard photos.indices.contains(currentIndex) else { return }
        let range = max(0, currentIndex - 2)...min(photos.count - 1, currentIndex + 4)
        let candidates = photos[range]
        let wantedIDs = Set(candidates.map(\.id))

        let focusedID = photos[currentIndex].id
        for (id, request) in requests {
            guard !request.operation.isExecuting else { continue }
            if request.completions.isEmpty && !wantedIDs.contains(id) {
                request.operation.cancel()
                requests.removeValue(forKey: id)
            } else if id == focusedID {
                request.operation.queuePriority = .veryHigh
            } else if wantedIDs.contains(id) {
                request.operation.queuePriority = request.completions.isEmpty ? .low : .normal
            } else {
                request.operation.queuePriority = .veryLow
            }
        }
        for photo in candidates where cachedPreview(for: photo) == nil && requests[photo.id] == nil {
            enqueue(
                id: photo.id, url: photo.currentURL, contentRevision: photo.contentRevision, completions: [],
                priority: photo.id == focusedID ? .veryHigh : .low
            )
        }
    }

    private func cancelRequest(for id: PhotoItem.ID) {
        guard let request = requests.removeValue(forKey: id) else { return }
        request.operation.cancel()
        request.completions.forEach { $0(nil) }
    }

    private func enqueue(
        id: PhotoItem.ID,
        url: URL,
        contentRevision: UUID,
        completions: [(NSImage?) -> Void],
        priority: Operation.QueuePriority = .low
    ) {
        let token = UUID()
        let decode = decode
        let operation = BlockOperation { [weak self] in
            let image = decode(url)
            Task { @MainActor [weak self] in
                self?.finish(id: id, url: url, token: token, image: image)
            }
        }
        operation.queuePriority = priority
        requests[id] = Request(url: url, contentRevision: contentRevision, token: token, operation: operation, completions: completions)
        decodeQueue.addOperation(operation)
    }

    private func finish(id: PhotoItem.ID, url: URL, token: UUID, image: CGImage?) {
        guard let request = requests[id], request.token == token else { return }
        requests.removeValue(forKey: id)

        // A sort may move the file before a queued decode opens its old path.
        if image == nil, request.url != url {
            enqueue(id: id, url: request.url, contentRevision: request.contentRevision, completions: request.completions, priority: request.operation.queuePriority)
            return
        }

        let preview = image.map {
            NSImage(cgImage: $0, size: NSSize(width: CGFloat($0.width), height: CGFloat($0.height)))
        }
        if let image, let preview {
            cache.setObject(preview, forKey: request.contentRevision as NSUUID, cost: image.bytesPerRow * image.height)
        } else {
            AppLogger.error("Preview unavailable for \(request.url.lastPathComponent)", category: .ui)
        }
        request.completions.forEach { $0(preview) }
    }

    nonisolated private static func decodeImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_000
        ] as CFDictionary)
    }
}
