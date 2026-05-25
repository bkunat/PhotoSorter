//
//  PhotoSorter
//

import Foundation

enum SessionLoadMode {
    case topLevelOnly
    case existingProject

    var measurementName: StaticString {
        switch self {
        case .topLevelOnly:
            "ScanPhotos"
        case .existingProject:
            "ScanExistingProject"
        }
    }
}

struct SessionLoadResult {
    let photos: [PhotoItem]
    let categories: [Category]
    let uncategorizedCount: Int
    let categorizedCount: Int

    var initialPhotoIndex: Int? {
        if let firstUncategorizedIndex = photos.firstIndex(where: { $0.status.isUncategorized }) {
            return firstUncategorizedIndex
        }

        return photos.indices.first
    }
}

struct SessionScanner {
    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
    private static let fallbackShortcutCandidates = Array("abcdefghijklmnopqrstuvwxyz0123456789")

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func buildSessionLoadResult(in directoryURL: URL, mode: SessionLoadMode) throws -> SessionLoadResult {
        let uncategorizedPhotos = try scanPhotos(in: directoryURL)

        guard mode == .existingProject else {
            return SessionLoadResult(
                photos: uncategorizedPhotos,
                categories: [],
                uncategorizedCount: uncategorizedPhotos.count,
                categorizedCount: 0
            )
        }

        let categoryDirectories = try immediateSubdirectoriesWithCurrentAccess(in: directoryURL)
        let categories = try makeExistingCategories(from: categoryDirectories)

        var categorizedPhotos: [PhotoItem] = []
        categorizedPhotos.reserveCapacity(categories.count)

        for category in categories {
            let nestedPhotos = try scanPhotos(in: category.destinationFolderURL).map { photo in
                PhotoItem(
                    id: photo.id,
                    originalURL: photo.originalURL,
                    currentURL: photo.currentURL,
                    filename: photo.filename,
                    status: .categorized(category.id)
                )
            }
            categorizedPhotos.append(contentsOf: nestedPhotos)
        }

        return SessionLoadResult(
            photos: uncategorizedPhotos + categorizedPhotos,
            categories: categories,
            uncategorizedCount: uncategorizedPhotos.count,
            categorizedCount: categorizedPhotos.count
        )
    }

    func scanPhotos(in directoryURL: URL) throws -> [PhotoItem] {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let photos = try contents
            .filter { url in
                guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else {
                    return false
                }

                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                return values.isRegularFile == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            .map { PhotoItem(originalURL: $0) }

        AppLogger.debug(
            "Scan in \(directoryURL.lastPathComponent) discovered \(photos.count) supported photo(s)",
            category: .session
        )

        return photos
    }

    func immediateSubdirectories(in directoryURL: URL) throws -> [URL] {
        let startedSecurityScope = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if startedSecurityScope {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        return try immediateSubdirectoriesWithCurrentAccess(in: directoryURL)
    }

    private func immediateSubdirectoriesWithCurrentAccess(in directoryURL: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try contents
            .filter { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                return values.isDirectory == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func makeExistingCategories(from directories: [URL]) throws -> [Category] {
        var usedShortcuts: Set<ShortcutKey> = []

        return try directories.map { directoryURL in
            guard let shortcut = makeShortcut(
                for: directoryURL.lastPathComponent,
                usedShortcuts: usedShortcuts
            ) else {
                AppLogger.error(
                    """
                    Existing project has \(directories.count) category folders, but only \
                    \(usedShortcuts.count) shortcuts could be assigned
                    """,
                    category: .session
                )
                throw SessionError.tooManyCategories(
                    categoryCount: directories.count,
                    shortcutCount: usedShortcuts.count
                )
            }

            usedShortcuts.insert(shortcut)

            AppLogger.info(
                "Loaded existing category \(directoryURL.lastPathComponent) with shortcut \(shortcut.displayValue)",
                category: .session
            )

            return Category(
                name: directoryURL.lastPathComponent,
                shortcut: shortcut,
                destinationFolderURL: directoryURL
            )
        }
    }

    private func makeShortcut(for categoryName: String, usedShortcuts: Set<ShortcutKey>) -> ShortcutKey? {
        var orderedCandidates: [String] = []
        var seenCandidates: Set<String> = []

        for scalar in categoryName.lowercased().unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            let candidate = String(scalar)
            if seenCandidates.insert(candidate).inserted {
                orderedCandidates.append(candidate)
            }
        }

        for candidateCharacter in Self.fallbackShortcutCandidates {
            let candidate = String(candidateCharacter)
            if seenCandidates.insert(candidate).inserted {
                orderedCandidates.append(candidate)
            }
        }

        for candidate in orderedCandidates {
            guard let shortcut = ShortcutKey(candidate) else { continue }
            guard !usedShortcuts.contains(shortcut) else { continue }
            return shortcut
        }

        return nil
    }
}
