//
//  PhotoSorter
//

import Foundation

struct CategoryMutationSupport {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func validatedCategoryInput(
        name: String,
        shortcut: String,
        categories: [Category],
        excluding excludedCategoryID: Category.ID?
    ) throws -> (name: String, shortcut: ShortcutKey) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SessionError.emptyCategoryName
        }

        guard isValidSinglePathComponent(trimmedName) else {
            throw SessionError.invalidCategoryName(trimmedName)
        }

        guard let parsedShortcut = ShortcutKey(shortcut) else {
            throw SessionError.unsupportedShortcut
        }

        guard !categories.contains(where: { category in
            guard category.id != excludedCategoryID else {
                return false
            }

            return category.name.compare(
                trimmedName,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }) else {
            throw SessionError.duplicateCategoryName(trimmedName)
        }

        guard !categories.contains(where: { category in
            guard category.id != excludedCategoryID else {
                return false
            }

            return category.shortcut == parsedShortcut
        }) else {
            throw SessionError.duplicateShortcut(parsedShortcut.displayValue)
        }

        return (trimmedName, parsedShortcut)
    }

    private func isValidSinglePathComponent(_ name: String) -> Bool {
        guard name != ".", name != ".." else {
            return false
        }

        guard name.range(of: "/") == nil else {
            return false
        }

        let validationRootURL = URL(fileURLWithPath: "/PhotoSorterCategoryValidationRoot", isDirectory: true)
            .standardizedFileURL
        let categoryURL = validationRootURL
            .appendingPathComponent(name, isDirectory: true)
            .standardizedFileURL

        return categoryURL.deletingLastPathComponent() == validationRootURL
            && categoryURL.lastPathComponent == name
    }

    func renameCategoryDirectoryIfNeeded(
        from oldDirectoryURL: URL,
        to newDirectoryURL: URL,
        categoryName: String
    ) throws {
        guard oldDirectoryURL.path != newDirectoryURL.path else {
            return
        }

        guard fileManager.fileExists(atPath: oldDirectoryURL.path) else {
            return
        }

        let isCaseOnlyRename = oldDirectoryURL.path.compare(
            newDirectoryURL.path,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame

        if isCaseOnlyRename == false, fileManager.fileExists(atPath: newDirectoryURL.path) {
            throw SessionError.categoryFolderConflict(newDirectoryURL.path)
        }

        do {
            if isCaseOnlyRename {
                let temporaryURL = oldDirectoryURL.deletingLastPathComponent()
                    .appendingPathComponent(".photosorter-rename-\(UUID().uuidString)", isDirectory: true)
                try fileManager.moveItem(at: oldDirectoryURL, to: temporaryURL)
                try fileManager.moveItem(at: temporaryURL, to: newDirectoryURL)
            } else {
                try fileManager.moveItem(at: oldDirectoryURL, to: newDirectoryURL)
            }
        } catch {
            throw SessionError.categoryRenameFailed(
                name: categoryName,
                underlying: error.localizedDescription
            )
        }

        AppLogger.info(
            "Renamed category folder from \(oldDirectoryURL.lastPathComponent) to \(newDirectoryURL.lastPathComponent)",
            category: .fileSystem
        )
    }

    func remapURLsForRenamedCategory(
        categoryID: Category.ID,
        oldDirectoryURL: URL,
        newDirectoryURL: URL,
        photos: inout [PhotoItem],
        undoHistory: inout [SortAction]
    ) {
        guard oldDirectoryURL.path != newDirectoryURL.path else {
            return
        }

        for index in photos.indices {
            guard photos[index].status.assignedCategoryID == categoryID else {
                continue
            }

            photos[index].currentURL = updatedURLByReplacingDirectory(
                in: photos[index].currentURL,
                from: oldDirectoryURL,
                to: newDirectoryURL
            )
        }

        for index in undoHistory.indices {
            guard undoHistory[index].categoryID == categoryID else {
                continue
            }

            undoHistory[index] = SortAction(
                photoID: undoHistory[index].photoID,
                categoryID: undoHistory[index].categoryID,
                sourceURL: undoHistory[index].sourceURL,
                destinationURL: updatedURLByReplacingDirectory(
                    in: undoHistory[index].destinationURL,
                    from: oldDirectoryURL,
                    to: newDirectoryURL
                )
            )
        }
    }

    private func updatedURLByReplacingDirectory(
        in url: URL,
        from oldDirectoryURL: URL,
        to newDirectoryURL: URL
    ) -> URL {
        let oldComponents = oldDirectoryURL.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents

        guard urlComponents.starts(with: oldComponents) else {
            return url
        }

        let relativeComponents = urlComponents.dropFirst(oldComponents.count)
        guard !relativeComponents.isEmpty else {
            return newDirectoryURL
        }

        return relativeComponents.reduce(newDirectoryURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
    }
}
