//
//  PhotoSorter
//

import Foundation

struct RecentDirectoryResolution {
    let url: URL
    let updatedDirectory: RecentDirectory?
}

struct RecentDirectoryPersistence {
    private static let defaultsKey = "recentDirectories"
    private static let maximumDirectories = 8

    let fileManager: FileManager
    let userDefaults: UserDefaults

    init(fileManager: FileManager = .default, userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
    }

    func loadPersistedRecentDirectories() -> [RecentDirectory] {
        guard let data = userDefaults.data(forKey: Self.defaultsKey) else {
            return []
        }

        do {
            let persistedDirectories = try JSONDecoder().decode([RecentDirectory].self, from: data)
            let validDirectories = Array(
                persistedDirectories
                    .compactMap(validateRecentDirectory)
                    .prefix(Self.maximumDirectories)
            )

            if validDirectories != persistedDirectories {
                persist(validDirectories)
            }

            return validDirectories
        } catch {
            AppLogger.error(
                "Failed to decode recent folders: \(error.localizedDescription)",
                category: .session
            )
            userDefaults.removeObject(forKey: Self.defaultsKey)
            return []
        }
    }

    func persist(_ directories: [RecentDirectory]) {
        guard !directories.isEmpty else {
            userDefaults.removeObject(forKey: Self.defaultsKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(directories)
            userDefaults.set(data, forKey: Self.defaultsKey)
        } catch {
            AppLogger.error(
                "Failed to persist recent folders: \(error.localizedDescription)",
                category: .session
            )
        }
    }

    func adding(_ directoryURL: URL, to directories: [RecentDirectory], openedAt: Date) throws -> [RecentDirectory] {
        let recentDirectory = try makeRecentDirectory(for: directoryURL, openedAt: openedAt)
        var updatedDirectories = directories
        updatedDirectories.removeAll { $0.path == recentDirectory.path }
        updatedDirectories.insert(recentDirectory, at: 0)

        if updatedDirectories.count > Self.maximumDirectories {
            updatedDirectories.removeSubrange(Self.maximumDirectories...)
        }

        return updatedDirectories
    }

    func resolvedAvailableURL(for recentDirectory: RecentDirectory) throws -> RecentDirectoryResolution {
        let resolution = try resolveBookmarkURL(for: recentDirectory)
        let resolvedURL = resolution.url

        guard directoryExists(at: resolvedURL) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directoryURL = normalizedDirectoryURL(from: resolvedURL)

        if resolution.isStale {
            AppLogger.notice(
                "Refreshing stale bookmark before reopening \(directoryURL.path)",
                category: .session
            )
            return try RecentDirectoryResolution(
                url: resolvedURL,
                updatedDirectory: makeRecentDirectory(
                    for: directoryURL,
                    openedAt: recentDirectory.lastOpenedAt
                )
            )
        }

        if recentDirectory.path != directoryURL.path
            || recentDirectory.displayName != directoryURL.lastPathComponent
        {
            return RecentDirectoryResolution(
                url: resolvedURL,
                updatedDirectory: RecentDirectory(
                    displayName: directoryURL.lastPathComponent,
                    path: directoryURL.path,
                    bookmarkData: recentDirectory.bookmarkData,
                    lastOpenedAt: recentDirectory.lastOpenedAt
                )
            )
        }

        return RecentDirectoryResolution(url: resolvedURL, updatedDirectory: nil)
    }

    func replacing(
        _ existingRecentDirectory: RecentDirectory,
        with updatedRecentDirectory: RecentDirectory,
        in directories: [RecentDirectory]
    ) -> [RecentDirectory] {
        var updatedDirectories = directories
        guard let index = updatedDirectories.firstIndex(where: { $0.path == existingRecentDirectory.path }) else {
            return directories
        }

        updatedDirectories[index] = updatedRecentDirectory
        return updatedDirectories
    }

    func removing(_ recentDirectory: RecentDirectory, from directories: [RecentDirectory]) -> [RecentDirectory] {
        directories.filter { $0.path != recentDirectory.path }
    }

    private func validateRecentDirectory(_ recentDirectory: RecentDirectory) -> RecentDirectory? {
        do {
            let resolution = try resolveBookmarkURL(for: recentDirectory)
            let resolvedURL = resolution.url

            guard directoryExists(at: resolvedURL) else {
                AppLogger.notice(
                    "Dropping missing recent folder \(recentDirectory.path)",
                    category: .session
                )
                return nil
            }

            let directoryURL = normalizedDirectoryURL(from: resolvedURL)

            if resolution.isStale {
                AppLogger.notice(
                    "Refreshing stale bookmark for \(directoryURL.path)",
                    category: .session
                )
                return try makeRecentDirectory(for: directoryURL, openedAt: recentDirectory.lastOpenedAt)
            }

            guard recentDirectory.path != directoryURL.path
                || recentDirectory.displayName != directoryURL.lastPathComponent
            else {
                return recentDirectory
            }

            return RecentDirectory(
                displayName: directoryURL.lastPathComponent,
                path: directoryURL.path,
                bookmarkData: recentDirectory.bookmarkData,
                lastOpenedAt: recentDirectory.lastOpenedAt
            )
        } catch {
            AppLogger.notice(
                """
                Dropping unresolved recent folder \(recentDirectory.path): \
                \(error.localizedDescription)
                """,
                category: .session
            )
            return nil
        }
    }

    private func makeRecentDirectory(for directoryURL: URL, openedAt: Date) throws -> RecentDirectory {
        let normalizedURL = normalizedDirectoryURL(from: directoryURL)
        return try RecentDirectory(
            displayName: normalizedURL.lastPathComponent,
            path: normalizedURL.path,
            bookmarkData: bookmarkData(for: normalizedURL),
            lastOpenedAt: openedAt
        )
    }

    private func bookmarkData(for directoryURL: URL) throws -> Data {
        do {
            return try directoryURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            AppLogger.notice(
                """
                Failed to create a security-scoped bookmark for \(directoryURL.path); \
                retrying with a regular bookmark
                """,
                category: .session
            )
            return try directoryURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private func resolveBookmarkURL(for recentDirectory: RecentDirectory) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: recentDirectory.bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            let url = try URL(
                resolvingBookmarkData: recentDirectory.bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        }
    }

    private func normalizedDirectoryURL(from directoryURL: URL) -> URL {
        directoryURL.resolvingSymlinksInPath().standardizedFileURL
    }

    private func directoryExists(at directoryURL: URL) -> Bool {
        let startedSecurityScope = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if startedSecurityScope {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
