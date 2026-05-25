//
//  PhotoSorter
//

import AppKit
import ImageIO

final class PhotoCarouselPreviewLoader {
    private struct PendingRequest {
        let requestsDisplayResolutionLog: Bool
        let completion: (NSImage?) -> Void
    }

    private let cache = NSCache<NSURL, NSImage>()
    private let stateQueue = DispatchQueue(label: "PhotoSorter.PhotoCarouselPreviewLoader.State")
    private let decodeQueue = DispatchQueue(
        label: "PhotoSorter.PhotoCarouselPreviewLoader.Decode",
        qos: .userInitiated,
        attributes: [.concurrent]
    )
    private let maximumThumbnailPixelSize: CGFloat = 1_600
    private var inFlightRequests: [NSURL: [PendingRequest]] = [:]

    init() {
        cache.countLimit = 48
    }

    func cachedPreview(for photoURL: URL) -> NSImage? {
        cache.object(forKey: photoURL as NSURL)
    }

    func loadPreview(
        for photo: PhotoItem,
        reasonDescription: String,
        completion: @escaping (NSImage?) -> Void
    ) {
        loadPreview(
            for: photo,
            requestsDisplayResolutionLog: true,
            reasonDescription: reasonDescription,
            completion: completion
        )
    }

    func preload(photos: [PhotoItem], around currentIndex: Int, previousCount: Int = 6, nextCount: Int = 10) {
        guard photos.indices.contains(currentIndex) else { return }

        let lowerBound = max(currentIndex - previousCount, photos.startIndex)
        let upperBound = min(currentIndex + nextCount, photos.index(before: photos.endIndex))
        let preloadCandidates = Array(photos[lowerBound...upperBound])
        let uncachedCandidates = preloadCandidates.filter { cachedPreview(for: $0.currentURL) == nil }

        guard uncachedCandidates.isEmpty == false else { return }

        let stopwatch = AppLogger.Stopwatch()
        AppLogger.debug(
            "Carousel preview preload scheduled for indices \(lowerBound + 1)-\(upperBound + 1) around \(currentIndex + 1) with \(uncachedCandidates.count) uncached previews",
            category: .ui
        )

        let completionGroup = DispatchGroup()
        for photo in uncachedCandidates {
            completionGroup.enter()
            loadPreview(
                for: photo,
                requestsDisplayResolutionLog: false,
                reasonDescription: "preload window around \(currentIndex + 1)"
            ) { _ in
                completionGroup.leave()
            }
        }

        completionGroup.notify(queue: .main) {
            AppLogger.debug(
                "Carousel preview preload completed for indices \(lowerBound + 1)-\(upperBound + 1) in \(stopwatch.elapsedMilliseconds) ms",
                category: .ui
            )
        }
    }

    private func loadPreview(
        for photo: PhotoItem,
        requestsDisplayResolutionLog: Bool,
        reasonDescription: String,
        completion: @escaping (NSImage?) -> Void
    ) {
        let cacheKey = photo.currentURL as NSURL

        if let cachedImage = cache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        stateQueue.async {
            if self.inFlightRequests[cacheKey] != nil {
                self.inFlightRequests[cacheKey, default: []].append(
                    PendingRequest(
                        requestsDisplayResolutionLog: requestsDisplayResolutionLog,
                        completion: completion
                    )
                )
                return
            }

            self.inFlightRequests[cacheKey] = [
                PendingRequest(
                    requestsDisplayResolutionLog: requestsDisplayResolutionLog,
                    completion: completion
                )
            ]
            self.decodeQueue.async {
                let stopwatch = AppLogger.Stopwatch()
                let image = self.makeDecodedPreview(for: photo.currentURL)

                if let image {
                    self.cache.setObject(image, forKey: cacheKey)
                } else {
                    AppLogger.error(
                        "Carousel preview unavailable for \(photo.filename) while handling \(reasonDescription)",
                        category: .ui
                    )
                }

                let pendingRequests = self.stateQueue.sync {
                    self.inFlightRequests.removeValue(forKey: cacheKey) ?? []
                }

                if requestsDisplayResolutionLog || pendingRequests.contains(where: \.requestsDisplayResolutionLog) {
                    AppLogger.debug(
                        "Carousel preview resolved for \(photo.filename) in \(stopwatch.elapsedMilliseconds) ms during \(reasonDescription)",
                        category: .ui
                    )
                }

                DispatchQueue.main.async {
                    pendingRequests.forEach { request in
                        request.completion(image)
                    }
                }
            }
        }
    }

    private func makeDecodedPreview(for photoURL: URL) -> NSImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(photoURL as CFURL, options) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumThumbnailPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        )
    }
}
