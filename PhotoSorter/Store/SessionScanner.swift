//
//  PhotoSorter
//

import Foundation

nonisolated enum SessionLoadMode: Sendable {
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

nonisolated struct SessionLoadResult: Sendable {
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

protocol SessionScanning: Sendable {
    nonisolated func immediateSubdirectories(in directoryURL: URL) throws -> [URL]
    nonisolated func buildSessionLoadResult(in directoryURL: URL, mode: SessionLoadMode, settings: CategorySettings?) throws -> SessionLoadResult
}

// FileManager directory reads are thread-safe; this scanner never changes its delegate.
nonisolated struct SessionScanner: SessionScanning, @unchecked Sendable {
    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
    private static let fallbackShortcutCandidates = Array("abcdefghijklmnopqrstuvwxyz0123456789")

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func buildSessionLoadResult(in directoryURL: URL, mode: SessionLoadMode, settings: CategorySettings? = nil) throws -> SessionLoadResult {
        let uncategorizedPhotos = try scanPhotos(in: directoryURL)

        let categoryDirectories = mode == .existingProject
            ? try immediateSubdirectoriesWithCurrentAccess(in: directoryURL)
            : []
        let categories = try makeExistingCategories(from: categoryDirectories, in: directoryURL, saved: settings?.categories ?? [])

        var categorizedPhotos: [PhotoItem] = []
        categorizedPhotos.reserveCapacity(categories.count)

        for category in categories {
            try Task.checkCancellation()
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: category.destinationFolderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
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
        try Task.checkCancellation()
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let photos = try contents
            .filter { url in
                try Task.checkCancellation()
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
        return try immediateSubdirectoriesWithCurrentAccess(in: directoryURL)
    }

    private func immediateSubdirectoriesWithCurrentAccess(in directoryURL: URL) throws -> [URL] {
        try Task.checkCancellation()
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try contents
            .filter { url in
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                return values.isDirectory == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func makeExistingCategories(from directories: [URL], in rootURL: URL, saved: [SavedCategory]) throws -> [Category] {
        var usedShortcuts: Set<ShortcutKey> = []
        var categories: [Category] = []
        var usedNames: Set<String> = []
        var usedIDs: Set<UUID> = []

        // Reserve saved keys before assigning keys to newly discovered folders.
        for entry in saved {
            var url = rootURL.appendingPathComponent(entry.name, isDirectory: true).standardizedFileURL
            guard !entry.name.isEmpty, entry.name != ".", entry.name != "..", !entry.name.contains("/"),
                  url.deletingLastPathComponent() == rootURL.standardizedFileURL,
                  !usedIDs.contains(entry.id) else { continue }
            if let actualDirectory = directories.first(where: { sameDirectory($0, url) }) {
                url = actualDirectory
            }
            let name = url.lastPathComponent
            guard !usedNames.contains(name) else { continue }
            let preferredShortcut = ShortcutKey(entry.shortcut)
            let shortcut = preferredShortcut.flatMap { usedShortcuts.contains($0) ? nil : $0 }
                ?? makeShortcut(for: name, usedShortcuts: usedShortcuts)
            guard let shortcut else {
                throw SessionError.tooManyCategories(categoryCount: saved.count, shortcutCount: usedShortcuts.count)
            }
            usedNames.insert(name)
            usedIDs.insert(entry.id)
            usedShortcuts.insert(shortcut)
            categories.append(Category(id: entry.id, name: name, shortcut: shortcut, destinationFolderURL: url))
        }

        for directoryURL in directories where !usedNames.contains(directoryURL.lastPathComponent) {
            try Task.checkCancellation()
            guard let shortcut = makeShortcut(for: directoryURL.lastPathComponent, usedShortcuts: usedShortcuts) else {
                throw SessionError.tooManyCategories(categoryCount: categories.count + 1, shortcutCount: usedShortcuts.count)
            }
            usedShortcuts.insert(shortcut)
            usedNames.insert(directoryURL.lastPathComponent)
            categories.append(Category(name: directoryURL.lastPathComponent, shortcut: shortcut, destinationFolderURL: directoryURL))
        }
        return categories
    }

    private func sameDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.standardizedFileURL == rhs.standardizedFileURL { return true }
        guard let left = try? lhs.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject,
              let right = try? rhs.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject else { return false }
        return left.isEqual(right)
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
