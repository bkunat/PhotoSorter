//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct ContentView: View {
    private static let minimumWindowWidth: CGFloat = 980
    private static let minimumEmptyContentHeight: CGFloat = 700
    private static let minimumLoadedContentHeight: CGFloat = 760

    @Bindable var store: SortSessionStore
    @State private var keyboardMonitor: Any?
    @State private var sidebarContentHeight: CGFloat = 0
    @State private var feedbackDismissTask: Task<Void, Never>?
    @State private var hasLoggedCompletionState = false

    private let folderPicker = FolderPicker()
    private let keyboardController = SessionKeyboardController()

    var body: some View {
        let stats = store.sessionStats

        WindowContentSplitView(
            sidebarMinWidth: 280,
            sidebarIdealWidth: 300,
            sidebarMaxWidth: 340,
            onSidebarContentHeightChange: updateSidebarContentHeight
        ) {
            sidebar(stats: stats)
        } mainContent: {
            SessionMainContentView(
                selectedDirectoryURL: store.selectedDirectoryURL,
                photos: store.photos,
                categories: store.categories,
                stats: stats,
                currentPhotoIndex: store.currentPhotoIndex,
                currentPhoto: store.currentPhoto,
                currentPhotoCategory: store.currentPhotoCategory,
                activeFeedback: store.activeFeedback,
                recentDirectories: store.recentDirectories,
                canUndo: store.canUndo,
                onChooseFolder: chooseFolder,
                onOpenRecentDirectory: store.openRecentDirectory(_:),
                onSelectPhoto: store.selectPhoto(at:)
            )
        }
        .frame(
            minWidth: Self.minimumWindowWidth,
            minHeight: minimumWindowVisibleContentHeight
        )
        .background(
            WindowMinimumSizeConfigurator(
                minimumVisibleContentSize: CGSize(
                    width: Self.minimumWindowWidth,
                    height: minimumWindowVisibleContentHeight
                )
            )
            .allowsHitTesting(false)
        )
        .toolbar {
            ToolbarItemGroup {
                Button("Choose Folder", systemImage: "folder") {
                    chooseFolder()
                }

                Button("Add Category", systemImage: "plus") {
                    store.openCategorySheet()
                }
                .disabled(!store.canCreateCategories)

                Button("Undo", systemImage: "arrow.uturn.backward") {
                    store.perform {
                        try store.undoLastCategorization()
                    }
                }
                .disabled(!store.canUndo)
            }
        }
        .sheet(isPresented: $store.isPresentingCategorySheet, onDismiss: store.dismissCategorySheet) {
            CategoryEditorSheet(
                mode: store.editingCategory == nil ? .create : .edit,
                initialName: store.editingCategory?.name ?? "",
                initialShortcut: store.editingCategory?.shortcut.rawValue ?? ""
            ) { name, shortcut in
                if let editingCategory = store.editingCategory {
                    try store.updateCategory(
                        id: editingCategory.id,
                        name: name,
                        shortcut: shortcut
                    )
                } else {
                    try store.createCategory(name: name, shortcut: shortcut)
                }
            } onCancel: {
                store.dismissCategorySheet()
            }
        }
        .confirmationDialog(
            "Open as Existing Project?",
            isPresented: pendingProjectPromptIsPresented,
            titleVisibility: .visible
        ) {
            Button("Use Existing Categories") {
                store.confirmPendingProjectOpen(asExistingProject: true)
            }

            Button("Scan Only Root Photos") {
                store.confirmPendingProjectOpen(asExistingProject: false)
            }

            Button("Cancel", role: .cancel) {
                store.dismissPendingProjectOpen()
            }
        } message: {
            if let pendingProjectOpen = store.pendingProjectOpen {
                Text(
                    """
                    "\(pendingProjectOpen.directoryURL.lastPathComponent)" already contains \
                    \(pendingProjectOpen.existingCategoryCount) folder\(pendingProjectOpen.existingCategoryCount == 1 ? "" : "s"). \
                    Use those folders as existing categories, or ignore them and scan only the photos in the root folder.
                    """
                )
            }
        }
        .alert(item: $store.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            installKeyboardMonitor()
            logCompletionStateIfNeeded(stats: stats)
        }
        .onDisappear {
            removeKeyboardMonitor()
            feedbackDismissTask?.cancel()
        }
        .onChange(of: store.activeFeedback?.id) { _, feedbackID in
            scheduleFeedbackDismissal(for: feedbackID)
        }
        .onChange(of: stats.isComplete) { _, isComplete in
            if isComplete {
                logCompletionStateIfNeeded(stats: store.sessionStats)
            } else {
                hasLoggedCompletionState = false
            }
        }
        .onChange(of: store.selectedDirectoryURL?.path) { _, newPath in
            let mode = newPath == nil ? "empty-session" : "loaded-session"
            let directoryName = store.selectedDirectoryURL?.lastPathComponent ?? "none"
            AppLogger.info(
                """
                Window minimum-height mode changed to \(mode) for directory \(directoryName); \
                photos=\(store.photos.count), categories=\(store.categories.count), \
                sidebarHeight=\(Int(ceil(sidebarContentHeight))), \
                minimumVisibleHeight=\(Int(ceil(minimumWindowVisibleContentHeight)))
                """,
                category: .ui
            )
        }
        .onChange(of: minimumWindowVisibleContentHeight) { oldValue, newValue in
            guard abs(newValue - oldValue) >= 1 else { return }

            AppLogger.debug(
                """
                Minimum visible window height changed from \(Int(ceil(oldValue))) to \
                \(Int(ceil(newValue))) with sidebarHeight=\(Int(ceil(sidebarContentHeight))) \
                and sessionLoaded=\(store.selectedDirectoryURL != nil)
                """,
                category: .ui
            )
        }
    }

    private func sidebar(stats: SessionStats) -> some View {
        SessionSidebarView(
            directoryURL: store.selectedDirectoryURL,
            categories: store.categories,
            stats: stats,
            canCreateCategories: store.canCreateCategories,
            canCategorizeCurrentPhoto: store.canCategorizeCurrentPhoto,
            onAddCategory: { store.openCategorySheet() },
            onEditCategory: { store.openCategorySheet(for: $0) },
            onCategorize: categorizeCurrentPhoto(with:)
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var minimumWindowVisibleContentHeight: CGFloat {
        let baseHeight = store.selectedDirectoryURL == nil
            ? Self.minimumEmptyContentHeight
            : Self.minimumLoadedContentHeight

        return max(baseHeight, ceil(sidebarContentHeight))
    }

    private func chooseFolder() {
        guard let directoryURL = folderPicker.chooseDirectory() else { return }
        store.openDirectory(directoryURL)
    }

    private func categorizeCurrentPhoto(with categoryID: Category.ID) {
        guard store.canCategorizeCurrentPhoto else { return }

        store.perform {
            try store.categorizeCurrentPhoto(with: categoryID)
        }
    }

    private func updateSidebarContentHeight(_ newHeight: CGFloat) {
        let roundedHeight = ceil(newHeight)
        guard abs(roundedHeight - sidebarContentHeight) >= 1 else { return }

        sidebarContentHeight = roundedHeight
        AppLogger.debug(
            "Sidebar intrinsic content height updated to \(Int(roundedHeight))",
            category: .ui
        )
    }

    private func scheduleFeedbackDismissal(for feedbackID: SessionFeedback.ID?) {
        feedbackDismissTask?.cancel()

        guard let feedbackID else { return }

        feedbackDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            store.clearActiveFeedback(matching: feedbackID)
        }
    }

    private func logCompletionStateIfNeeded(stats: SessionStats) {
        guard stats.isComplete, !hasLoggedCompletionState else { return }

        hasLoggedCompletionState = true
        AppLogger.notice(
            """
            Showing completion state with \(stats.sortedCount) sorted photo(s) \
            across \(stats.usedCategoryCount) used categor\(stats.usedCategoryCount == 1 ? "y" : "ies")
            """,
            category: .ui
        )
    }

    private func installKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard shouldHandleGlobalShortcut(for: event) else {
                return event
            }

            return keyboardController.handle(event, store: store) ? nil : event
        }
    }

    private func removeKeyboardMonitor() {
        guard let keyboardMonitor else { return }

        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
    }

    private func shouldHandleGlobalShortcut(for event: NSEvent) -> Bool {
        guard let textView = event.window?.firstResponder as? NSTextView else {
            return true
        }

        return !textView.isEditable
    }

    private var pendingProjectPromptIsPresented: Binding<Bool> {
        Binding(
            get: { store.pendingProjectOpen != nil },
            set: { isPresented in
                if !isPresented {
                    store.dismissPendingProjectOpen()
                }
            }
        )
    }
}

#Preview {
    ContentView(store: SortSessionStore())
}
