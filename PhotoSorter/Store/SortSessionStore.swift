//
//  PhotoSorter
//

import Foundation
import Observation

struct PendingProjectOpen: Identifiable {
    let id = UUID()
    let directoryURL: URL
    let existingCategoryCount: Int
}

struct SessionFeedback: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let categoryID: Category.ID?
    let systemImage: String
}

nonisolated private enum DirectoryOpenResult: Sendable {
    case prompt(Int)
    case session(SessionLoadResult, SessionLoadMode)
}

@MainActor
@Observable
final class SortSessionStore {
    var selectedDirectoryURL: URL?
    var photos: [PhotoItem] = []
    var currentPhotoIndex: Int?
    var categories: [Category] = []
    var undoHistory: [SortAction] = []
    var isPresentingCategorySheet = false
    var editingCategoryID: Category.ID?
    var activeAlert: SessionAlert?
    var activeFeedback: SessionFeedback?
    var pendingProjectOpen: PendingProjectOpen?
    var recentDirectories: [RecentDirectory] = []
    private(set) var isLoading = false

    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let scanner: any SessionScanning
    @ObservationIgnored private let categorySettingsPersistence: CategorySettingsPersistence
    @ObservationIgnored private var includesOtherFolders = false
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    @ObservationIgnored private var loadingID: UUID?
    @ObservationIgnored private let recentDirectoryPersistence: RecentDirectoryPersistence
    @ObservationIgnored private let categoryMutationSupport: CategoryMutationSupport
    @ObservationIgnored private let securityScopedResourceAccess: SecurityScopedResourceAccess
    @ObservationIgnored private var scopedDirectoryURL: URL?

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        securityScopedResourceAccess: SecurityScopedResourceAccess? = nil,
        scanner: (any SessionScanning)? = nil
    ) {
        self.fileManager = fileManager
        self.securityScopedResourceAccess = securityScopedResourceAccess ?? DefaultSecurityScopedResourceAccess()
        self.scanner = scanner ?? SessionScanner(fileManager: fileManager)
        categorySettingsPersistence = CategorySettingsPersistence(userDefaults: userDefaults)
        recentDirectoryPersistence = RecentDirectoryPersistence(
            fileManager: fileManager,
            userDefaults: userDefaults
        )
        categoryMutationSupport = CategoryMutationSupport(fileManager: fileManager)
        recentDirectories = recentDirectoryPersistence.loadPersistedRecentDirectories()
        AppLogger.debug(
            """
            SortSessionStore initialized with \(recentDirectories.count) recent \
            director\(recentDirectories.count == 1 ? "y" : "ies")
            """,
            category: .session
        )
    }

    deinit {
        loadingTask?.cancel()
        if let scopedDirectoryURL {
            securityScopedResourceAccess.stopAccessing(scopedDirectoryURL)
        }
    }

    var currentPhoto: PhotoItem? {
        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else {
            return nil
        }

        return photos[currentPhotoIndex]
    }

    var currentPhotoCategory: Category? {
        guard let categoryID = currentPhoto?.status.assignedCategoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    var editingCategory: Category? {
        guard let editingCategoryID else {
            return nil
        }

        return categories.first { $0.id == editingCategoryID }
    }

    var positionText: String {
        guard let currentPhotoIndex else { return "0 / \(photos.count)" }
        return "\(currentPhotoIndex + 1) / \(photos.count)"
    }

    var sessionStats: SessionStats {
        SessionStats(photos: photos, categories: categories)
    }

    var remainingUnsortedCount: Int {
        sessionStats.remainingCount
    }

    var sortedCount: Int {
        sessionStats.sortedCount
    }

    var sortingProgress: Double {
        sessionStats.progress
    }

    var sortingProgressPercent: Int {
        sessionStats.progressPercent
    }

    var categorySortCounts: [(category: Category, count: Int)] {
        sessionStats.categoryCounts
    }

    var isComplete: Bool {
        sessionStats.isComplete
    }

    var canUndo: Bool {
        !isLoading && !undoHistory.isEmpty
    }

    var canCreateCategories: Bool {
        !isLoading && selectedDirectoryURL != nil
    }

    var canCategorizeCurrentPhoto: Bool {
        guard !categories.isEmpty else { return false }
        return !isLoading && currentPhoto != nil
    }

    var canRemoveCurrentPhotoCategory: Bool {
        !isLoading && currentPhoto?.status.assignedCategoryID != nil
    }

    func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch let error as SessionError {
            present(error)
        } catch {
            present(.unexpected(error.localizedDescription))
        }
    }

    func openDirectory(_ directoryURL: URL) {
        startLoading(directoryURL)
    }

    func openRecentDirectory(_ recentDirectory: RecentDirectory) {
        cancelLoading()
        pendingProjectOpen = nil
        AppLogger.info(
            "Attempting to reopen recent folder \(recentDirectory.path)",
            category: .session
        )

        perform {
            let resolution: RecentDirectoryResolution
            do {
                resolution = try recentDirectoryPersistence.resolvedAvailableURL(for: recentDirectory)
            } catch {
                AppLogger.notice(
                    """
                    Removing unavailable recent folder \(recentDirectory.path): \
                    \(error.localizedDescription)
                    """,
                    category: .session
                )
                removeRecentDirectory(matching: recentDirectory)
                throw SessionError.recentDirectoryUnavailable(recentDirectory.displayName)
            }

            if let updatedDirectory = resolution.updatedDirectory {
                replaceRecentDirectory(recentDirectory, with: updatedDirectory)
            }

            startLoading(resolution.url)
        }
    }

    func openCategorySheet(for categoryID: Category.ID? = nil) {
        guard !isLoading else { return }
        guard selectedDirectoryURL != nil else {
            present(.noFolderSelected)
            return
        }

        if let categoryID, categories.contains(where: { $0.id == categoryID }) == false {
            present(.invalidCategory)
            return
        }

        editingCategoryID = categoryID
        AppLogger.debug(
            "\(categoryID == nil ? "Opening" : "Editing") category sheet",
            category: .ui
        )
        isPresentingCategorySheet = true
    }

    func dismissCategorySheet() {
        isPresentingCategorySheet = false
        editingCategoryID = nil
    }

    func loadSession(from directoryURL: URL) throws {
        try loadSession(from: directoryURL, mode: .topLevelOnly)
    }

    func loadExistingProject(from directoryURL: URL) throws {
        try loadSession(from: directoryURL, mode: .existingProject)
    }

    func confirmPendingProjectOpen(asExistingProject: Bool) {
        guard let pendingProjectOpen else { return }

        self.pendingProjectOpen = nil

        AppLogger.info(
            """
            Opening \(pendingProjectOpen.directoryURL.lastPathComponent) \
            as \(asExistingProject ? "an existing project" : "a flat folder")
            """,
            category: .session
        )

        startLoading(pendingProjectOpen.directoryURL, mode: asExistingProject ? .existingProject : .topLevelOnly)
    }

    func dismissPendingProjectOpen() {
        guard let pendingProjectOpen else { return }

        AppLogger.debug(
            "Dismissed existing project prompt for \(pendingProjectOpen.directoryURL.lastPathComponent)",
            category: .ui
        )
        self.pendingProjectOpen = nil
    }

    private func loadSession(from directoryURL: URL, mode: SessionLoadMode) throws {
        cancelLoading()
        let previousScopedDirectoryURL = scopedDirectoryURL
        let startedSecurityScope = securityScopedResourceAccess.startAccessing(directoryURL)

        do {
            let scanMeasurement = try AppLogger.measure(mode.measurementName, category: .performance) {
                try scanner.buildSessionLoadResult(in: directoryURL, mode: mode, settings: categorySettingsPersistence.load(for: directoryURL))
            }
            let session = scanMeasurement.value
            replaceScopedDirectory(
                with: directoryURL,
                startedSecurityScope: startedSecurityScope,
                previousScopedDirectoryURL: previousScopedDirectoryURL
            )

            applySession(session, directoryURL: directoryURL, mode: mode)

            AppLogger.info(
                """
                Loaded \(mode == .existingProject ? "existing project" : "session") for \
                \(directoryURL.lastPathComponent) with \(session.uncategorizedCount) uncategorized \
                photo(s), \(session.categorizedCount) categorized photo(s), and \
                \(session.categories.count) categor\(session.categories.count == 1 ? "y" : "ies") \
                in \(scanMeasurement.durationMilliseconds) ms
                """,
                category: .session
            )
        } catch let error as SessionError {
            if startedSecurityScope {
                securityScopedResourceAccess.stopAccessing(directoryURL)
            }

            throw error
        } catch {
            if startedSecurityScope {
                securityScopedResourceAccess.stopAccessing(directoryURL)
            }

            throw SessionError.scanFailed(
                folderName: directoryURL.lastPathComponent,
                underlying: error.localizedDescription
            )
        }
    }

    func createCategory(name: String, shortcut: String) throws {
        guard !isLoading else { return }
        guard let selectedDirectoryURL else {
            throw SessionError.noFolderSelected
        }

        let (trimmedName, parsedShortcut) = try categoryMutationSupport.validatedCategoryInput(
            name: name,
            shortcut: shortcut,
            categories: categories,
            excluding: nil
        )

        let destinationFolderURL = selectedDirectoryURL.appendingPathComponent(trimmedName, isDirectory: true)
        categories.append(
            Category(
                name: trimmedName,
                shortcut: parsedShortcut,
                destinationFolderURL: destinationFolderURL
            )
        )
        persistCategorySettings()
        dismissCategorySheet()

        AppLogger.info(
            "Created category \(trimmedName) with shortcut \(parsedShortcut.displayValue)",
            category: .session
        )
    }

    func updateCategory(
        id: Category.ID,
        name: String,
        shortcut: String
    ) throws {
        guard !isLoading else { return }
        guard let selectedDirectoryURL else {
            throw SessionError.noFolderSelected
        }

        guard let categoryIndex = categories.firstIndex(where: { $0.id == id }) else {
            throw SessionError.invalidCategory
        }

        let existingCategory = categories[categoryIndex]
        let (trimmedName, parsedShortcut) = try categoryMutationSupport.validatedCategoryInput(
            name: name,
            shortcut: shortcut,
            categories: categories,
            excluding: id
        )
        let updatedFolderURL = selectedDirectoryURL.appendingPathComponent(trimmedName, isDirectory: true)

        AppLogger.info(
            """
            Updating category \(existingCategory.name) to \(trimmedName), shortcut \
            \(parsedShortcut.displayValue)
            """,
            category: .session
        )

        try categoryMutationSupport.renameCategoryDirectoryIfNeeded(
            from: existingCategory.destinationFolderURL,
            to: updatedFolderURL,
            categoryName: existingCategory.name
        )

        categoryMutationSupport.remapURLsForRenamedCategory(
            categoryID: existingCategory.id,
            oldDirectoryURL: existingCategory.destinationFolderURL,
            newDirectoryURL: updatedFolderURL,
            photos: &photos,
            undoHistory: &undoHistory
        )

        categories[categoryIndex].name = trimmedName
        categories[categoryIndex].shortcut = parsedShortcut
        categories[categoryIndex].destinationFolderURL = updatedFolderURL
        persistCategorySettings()
        dismissCategorySheet()

        AppLogger.info(
            "Updated category \(trimmedName) with shortcut \(parsedShortcut.displayValue)",
            category: .session
        )
    }

    func categorizeCurrentPhoto(with categoryID: Category.ID) throws {
        guard !isLoading else { return }
        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else {
            throw SessionError.noCurrentPhoto
        }

        guard let category = categories.first(where: { $0.id == categoryID }) else {
            throw SessionError.invalidCategory
        }

        guard photos[currentPhotoIndex].status != .categorized(categoryID) else { return }

        let photo = photos[currentPhotoIndex]
        let sourceURL = photo.currentURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SessionError.sourceFileMissing(photo.filename)
        }

        AppLogger.info(
            "Categorizing \(photo.filename) into \(category.name)",
            category: .fileSystem
        )

        try fileManager.createDirectory(
            at: category.destinationFolderURL,
            withIntermediateDirectories: true
        )

        let destinationURL = category.destinationFolderURL.appendingPathComponent(photo.filename)
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw SessionError.destinationConflict(destinationURL.path)
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw SessionError.moveFailed(
                filename: photo.filename,
                underlying: error.localizedDescription
            )
        }

        photos[currentPhotoIndex].currentURL = destinationURL
        photos[currentPhotoIndex].status = .categorized(category.id)
        undoHistory.append(
            SortAction(
                photoID: photo.id,
                sourceURL: sourceURL,
                destinationURL: destinationURL,
                previousStatus: photo.status,
                nextStatus: .categorized(category.id)
            )
        )
        if photo.status.isUncategorized {
            setCurrentPhotoIndex(nextUnsortedIndex(after: currentPhotoIndex) ?? currentPhotoIndex)
        }
        activeFeedback = SessionFeedback(
            message: "Moved \(photo.filename) to \(category.name)",
            categoryID: category.id,
            systemImage: "checkmark.circle.fill"
        )

        AppLogger.info(
            "Moved \(photo.filename) to \(destinationURL.path)",
            category: .fileSystem
        )

        if photo.status.isUncategorized && isComplete {
            activeFeedback = SessionFeedback(
                message: "Sorting complete",
                categoryID: nil,
                systemImage: "checkmark.seal.fill"
            )
            AppLogger.notice("Sorting session completed", category: .session)
        }
    }

    func undoLastCategorization() throws {
        guard !isLoading else { return }
        guard let lastAction = undoHistory.last else {
            throw SessionError.nothingToUndo
        }

        guard let photoIndex = photos.firstIndex(where: { $0.id == lastAction.photoID }) else {
            throw SessionError.noCurrentPhoto
        }

        guard fileManager.fileExists(atPath: lastAction.destinationURL.path) else {
            throw SessionError.undoSourceMissing(lastAction.destinationURL.lastPathComponent)
        }

        guard !fileManager.fileExists(atPath: lastAction.sourceURL.path) else {
            throw SessionError.undoConflict(lastAction.sourceURL.path)
        }

        AppLogger.info(
            "Undoing categorization for \(lastAction.sourceURL.lastPathComponent)",
            category: .fileSystem
        )

        do {
            try fileManager.moveItem(at: lastAction.destinationURL, to: lastAction.sourceURL)
        } catch {
            throw SessionError.undoFailed(
                filename: lastAction.sourceURL.lastPathComponent,
                underlying: error.localizedDescription
            )
        }

        photos[photoIndex].currentURL = lastAction.sourceURL
        photos[photoIndex].status = lastAction.previousStatus
        setCurrentPhotoIndex(photoIndex)
        undoHistory.removeLast()
        activeFeedback = SessionFeedback(
            message: "Restored \(lastAction.sourceURL.lastPathComponent)",
            categoryID: lastAction.previousStatus.assignedCategoryID,
            systemImage: "arrow.uturn.backward.circle.fill"
        )

        AppLogger.info(
            "Restored \(lastAction.sourceURL.lastPathComponent) to \(lastAction.sourceURL.path)",
            category: .fileSystem
        )
    }

    func removeCategoryFromCurrentPhoto() throws {
        guard !isLoading else { return }
        guard let selectedDirectoryURL else {
            throw SessionError.noFolderSelected
        }

        guard let currentPhotoIndex, photos.indices.contains(currentPhotoIndex) else {
            throw SessionError.noCurrentPhoto
        }

        guard let categoryID = photos[currentPhotoIndex].status.assignedCategoryID else {
            throw SessionError.noCurrentPhoto
        }

        let photo = photos[currentPhotoIndex]
        let sourceURL = photo.currentURL
        let destinationURL = selectedDirectoryURL.appendingPathComponent(photo.filename)
        let categoryName = categories.first(where: { $0.id == categoryID })?.name ?? "unknown category"

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SessionError.undoSourceMissing(sourceURL.lastPathComponent)
        }

        guard sourceURL != destinationURL else {
            photos[currentPhotoIndex].status = .uncategorized
            undoHistory.removeAll { $0.photoID == photo.id }
            activeFeedback = SessionFeedback(
                message: "Returned \(photo.filename) to Unsorted",
                categoryID: nil,
                systemImage: "arrow.down.forward.circle.fill"
            )
            return
        }

        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw SessionError.undoConflict(destinationURL.path)
        }

        AppLogger.info(
            "Removing category \(categoryName) from \(photo.filename)",
            category: .fileSystem
        )

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw SessionError.undoFailed(
                filename: photo.filename,
                underlying: error.localizedDescription
            )
        }

        photos[currentPhotoIndex].currentURL = destinationURL
        photos[currentPhotoIndex].status = .uncategorized
        undoHistory.append(SortAction(
            photoID: photo.id,
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            previousStatus: photo.status,
            nextStatus: .uncategorized
        ))
        setCurrentPhotoIndex(currentPhotoIndex)
        activeFeedback = SessionFeedback(
            message: "Returned \(photo.filename) to Unsorted",
            categoryID: nil,
            systemImage: "arrow.down.forward.circle.fill"
        )

        AppLogger.info(
            "Returned \(photo.filename) to the uncategorized root at \(destinationURL.path)",
            category: .fileSystem
        )
    }

    func nextPhoto() {
        guard let currentPhotoIndex else { return }
        guard currentPhotoIndex < photos.count - 1 else { return }
        setCurrentPhotoIndex(currentPhotoIndex + 1)
    }

    func previousPhoto() {
        guard let currentPhotoIndex else { return }
        guard currentPhotoIndex > 0 else { return }
        setCurrentPhotoIndex(currentPhotoIndex - 1)
    }

    func selectPhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        guard currentPhotoIndex != index else { return }
        setCurrentPhotoIndex(index)
    }

    func clearActiveFeedback(matching feedbackID: SessionFeedback.ID? = nil) {
        guard let activeFeedback else { return }
        guard feedbackID == nil || activeFeedback.id == feedbackID else { return }
        self.activeFeedback = nil
    }

    func cancelLoading() {
        if isLoading { AppLogger.debug("Cancelled folder loading", category: .session) }
        loadingTask?.cancel()
        loadingTask = nil
        loadingID = nil
        isLoading = false
    }

    private func startLoading(_ directoryURL: URL, mode: SessionLoadMode? = nil) {
        cancelLoading()
        pendingProjectOpen = nil
        activeAlert = nil
        let id = UUID()
        loadingID = id
        isLoading = true
        let settings = categorySettingsPersistence.load(for: directoryURL)
        let scanner = scanner
        let securityAccess = securityScopedResourceAccess
        let startedSecurityScope = securityAccess.startAccessing(directoryURL)
        let stopwatch = AppLogger.Stopwatch()
        AppLogger.info("Opening folder \(directoryURL.lastPathComponent)", category: .session)

        let worker = Task.detached(priority: .userInitiated) { () throws -> DirectoryOpenResult in
            try Task.checkCancellation()
            let resolvedMode: SessionLoadMode
            if let mode {
                resolvedMode = mode
            } else if let settings {
                resolvedMode = settings.includesOtherFolders ? .existingProject : .topLevelOnly
            } else {
                let directories = try scanner.immediateSubdirectories(in: directoryURL)
                if !directories.isEmpty { return .prompt(directories.count) }
                resolvedMode = .topLevelOnly
            }
            let session = try scanner.buildSessionLoadResult(in: directoryURL, mode: resolvedMode, settings: settings)
            try Task.checkCancellation()
            return .session(session, resolvedMode)
        }
        loadingTask = Task { [weak self] in
            let result = await withTaskCancellationHandler {
                await worker.result
            } onCancel: {
                worker.cancel()
            }
            guard let self, self.loadingID == id, !Task.isCancelled else {
                if startedSecurityScope { securityAccess.stopAccessing(directoryURL) }
                return
            }
            self.loadingTask = nil
            self.loadingID = nil
            self.isLoading = false
            AppLogger.debug("Folder load finished in \(stopwatch.elapsedMilliseconds) ms", category: .performance)
            switch result {
            case let .success(.session(session, mode)):
                self.replaceScopedDirectory(with: directoryURL, startedSecurityScope: startedSecurityScope, previousScopedDirectoryURL: self.scopedDirectoryURL)
                self.applySession(session, directoryURL: directoryURL, mode: mode)
            case let .success(.prompt(count)):
                if startedSecurityScope { securityAccess.stopAccessing(directoryURL) }
                self.pendingProjectOpen = PendingProjectOpen(directoryURL: directoryURL, existingCategoryCount: count)
            case let .failure(error):
                if startedSecurityScope { securityAccess.stopAccessing(directoryURL) }
                if !(error is CancellationError) {
                    self.present((error as? SessionError) ?? .scanFailed(folderName: directoryURL.lastPathComponent, underlying: error.localizedDescription))
                }
            }
        }
    }

    private func applySession(_ session: SessionLoadResult, directoryURL: URL, mode: SessionLoadMode) {
        selectedDirectoryURL = directoryURL
        photos = session.photos
        currentPhotoIndex = session.initialPhotoIndex
        categories = session.categories
        includesOtherFolders = mode == .existingProject
        undoHistory = []
        isPresentingCategorySheet = false
        editingCategoryID = nil
        activeAlert = nil
        activeFeedback = nil
        pendingProjectOpen = nil
        persistCategorySettings()
        rememberRecentDirectory(directoryURL)
        AppLogger.info("Loaded \(session.photos.count) photos and \(session.categories.count) categories from \(directoryURL.lastPathComponent)", category: .session)
    }

    private func persistCategorySettings() {
        guard let selectedDirectoryURL else { return }
        categorySettingsPersistence.save(categories: categories, includesOtherFolders: includesOtherFolders, for: selectedDirectoryURL)
    }

    private func rememberRecentDirectory(_ directoryURL: URL) {
        do {
            recentDirectories = try recentDirectoryPersistence.adding(
                directoryURL,
                to: recentDirectories,
                openedAt: .now
            )
            recentDirectoryPersistence.persist(recentDirectories)
            AppLogger.debug(
                "Stored recent folder \(directoryURL.path)",
                category: .session
            )
        } catch {
            AppLogger.error(
                """
                Failed to store recent folder \(directoryURL.path): \
                \(error.localizedDescription)
                """,
                category: .session
            )
        }
    }

    private func replaceRecentDirectory(
        _ existingRecentDirectory: RecentDirectory,
        with updatedRecentDirectory: RecentDirectory
    ) {
        recentDirectories = recentDirectoryPersistence.replacing(
            existingRecentDirectory,
            with: updatedRecentDirectory,
            in: recentDirectories
        )
        recentDirectoryPersistence.persist(recentDirectories)
    }

    private func removeRecentDirectory(matching recentDirectory: RecentDirectory) {
        let originalCount = recentDirectories.count
        recentDirectories = recentDirectoryPersistence.removing(recentDirectory, from: recentDirectories)

        guard recentDirectories.count != originalCount else {
            return
        }

        recentDirectoryPersistence.persist(recentDirectories)
        AppLogger.info(
            "Removed unavailable recent folder \(recentDirectory.path)",
            category: .session
        )
    }

    private func nextUnsortedIndex(after currentIndex: Int) -> Int? {
        let trailingIndices = photos.indices.dropFirst(currentIndex + 1)
        if let nextIndex = trailingIndices.first(where: { photos[$0].status.isUncategorized }) {
            return nextIndex
        }

        return photos.indices.first(where: { photos[$0].status.isUncategorized })
    }

    private func setCurrentPhotoIndex(_ index: Int?) {
        if currentPhotoIndex != index {
            if let index, photos.indices.contains(index) {
                AppLogger.debug(
                    "Showing photo \(index + 1) of \(photos.count): \(photos[index].filename)",
                    category: .ui
                )
            } else if index == nil {
                AppLogger.debug("Cleared current photo selection", category: .ui)
            }
        }

        currentPhotoIndex = index
    }

    private func replaceScopedDirectory(
        with directoryURL: URL,
        startedSecurityScope: Bool,
        previousScopedDirectoryURL: URL?
    ) {
        if startedSecurityScope {
            scopedDirectoryURL = directoryURL
        } else if previousScopedDirectoryURL == directoryURL {
            scopedDirectoryURL = previousScopedDirectoryURL
        } else {
            scopedDirectoryURL = nil
        }

        guard let previousScopedDirectoryURL else {
            return
        }

        guard previousScopedDirectoryURL != directoryURL else {
            if startedSecurityScope {
                AppLogger.debug(
                    "Balanced previous security scope for reloaded directory \(previousScopedDirectoryURL.path)",
                    category: .session
                )
                securityScopedResourceAccess.stopAccessing(previousScopedDirectoryURL)
            }
            return
        }

        AppLogger.debug(
            "Releasing security scope for \(previousScopedDirectoryURL.path)",
            category: .session
        )
        securityScopedResourceAccess.stopAccessing(previousScopedDirectoryURL)
    }

    private func present(_ error: SessionError) {
        let details = [error.errorDescription, error.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: " | ")
        AppLogger.error("\(error.alertTitle): \(details)", category: .session)
        activeAlert = SessionAlert(error: error)
    }
}
