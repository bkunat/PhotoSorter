//
//  PhotoSorter
//

import AppKit
import QuickLook
import QuickLookUI
import SwiftUI

struct ContentView: View {
    @Bindable var store: SortSessionStore
    @State private var previewURL: URL?
    @State private var showsKeyboardHelp = false
    @State private var editingPhoto: PhotoItem?
    @State private var photoPendingDeletion: PhotoItem?

    private let folderPicker = FolderPicker()
    private let keyboardController = SessionKeyboardController()

    var body: some View {
        let stats = store.sessionStats

        HSplitView {
            ScrollView {
                SessionSidebarView(
                    directoryURL: store.selectedDirectoryURL,
                    categories: store.categories,
                    stats: stats,
                    currentCategoryID: store.currentPhotoCategory?.id,
                    canCreateCategories: store.canCreateCategories,
                    canCategorizeCurrentPhoto: store.canCategorizeCurrentPhoto,
                    onAddCategory: { store.openCategorySheet() },
                    onEditCategory: { store.openCategorySheet(for: $0) },
                    onCategorize: categorizeCurrentPhoto(with:)
                )
                .padding(18)
            }
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 320)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))

            SessionMainContentView(
                selectedDirectoryURL: store.selectedDirectoryURL,
                photos: store.photos,
                categories: store.categories,
                stats: stats,
                currentPhotoIndex: store.currentPhotoIndex,
                activeFeedback: store.activeFeedback,
                recentDirectories: store.recentDirectories,
                onChooseFolder: chooseFolder,
                onOpenRecentDirectory: store.openRecentDirectory(_:),
                onSelectPhoto: store.selectPhoto(at:),
                onPhotoAction: handlePhotoAction
            )
            .frame(minWidth: 500)
        }
        .disabled(store.isLoading)
        .overlay {
            if store.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Opening folder…")
                        .font(.headline)
                    Button("Cancel", action: store.cancelLoading)
                        .keyboardShortcut(.cancelAction)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(minWidth: 780, minHeight: 540)
        .navigationTitle(store.selectedDirectoryURL?.lastPathComponent ?? "PhotoSorter")
        .background(SessionKeyboardMonitor { event in
            guard sessionCommandsEnabled else { return false }
            if event.keyCode == 49, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
               !event.isARepeat, store.currentPhoto != nil {
                previewURL = store.currentPhoto?.currentURL
                return true
            }
            return keyboardController.handle(event, store: store)
        })
        .quickLookPreview($previewURL)
        .focusedSceneValue(\.sessionCommandsEnabled, sessionCommandsEnabled)
        .toolbar {
            ToolbarItemGroup {
                Button("Choose Folder", systemImage: "folder", action: chooseFolder)
                    .help("Choose a folder (⌘O)")
                Button("Add Category", systemImage: "plus") { store.openCategorySheet() }
                    .disabled(!store.canCreateCategories)
                    .help("Add a category (⌘N)")
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    store.perform { try store.undoLastAction() }
                }
                .disabled(!store.canUndo)
                .help("Undo the last edit, deletion, or move (⌘Z)")
            }
            ToolbarItemGroup {
                Button("Edit", systemImage: "slider.horizontal.3") {
                    previewURL = nil
                    editingPhoto = store.currentPhoto
                }
                .labelStyle(.titleAndIcon)
                .keyboardShortcut("e")
                .disabled(store.currentPhoto == nil || !sessionCommandsEnabled)
                .help("Edit the selected photo (⌘E)")
                Button("Delete Photo", systemImage: "trash") {
                    photoPendingDeletion = store.currentPhoto
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.currentPhoto == nil || !sessionCommandsEnabled)
                .help("Delete the selected photo with session undo (⌘⌫)")
                Button("Return to Unsorted", systemImage: "tray.and.arrow.down") {
                    store.perform { try store.removeCategoryFromCurrentPhoto() }
                }
                .disabled(!store.canRemoveCurrentPhotoCategory)
                .help("Move this photo back to the chosen folder (Delete)")
                Button("Quick Look", systemImage: "eye") { previewURL = store.currentPhoto?.currentURL }
                    .disabled(store.currentPhoto == nil || store.isLoading)
                    .help("Inspect the selected photo (Space)")
                Button("Show in Finder", systemImage: "folder.badge.gearshape") {
                    guard let url = store.currentPhoto?.currentURL ?? store.selectedDirectoryURL else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .disabled(store.selectedDirectoryURL == nil || store.isLoading)
                Button("Show Recovery Folder", systemImage: "externaldrive.badge.timemachine") {
                    NSWorkspace.shared.open(store.recoveryDirectoryURL)
                }
                .disabled(!FileManager.default.fileExists(atPath: store.recoveryDirectoryURL.path))
                .help("Show retained originals and deleted photos in Finder")
                Button("Keyboard Shortcuts", systemImage: "keyboard") { showsKeyboardHelp.toggle() }
                    .popover(isPresented: $showsKeyboardHelp) { KeyboardShortcutsPanelView().padding(20) }
            }
        }
        .sheet(isPresented: $store.isPresentingCategorySheet, onDismiss: store.dismissCategorySheet) {
            CategoryEditorSheet(
                mode: store.editingCategory == nil ? .create : .edit,
                initialName: store.editingCategory?.name ?? "",
                initialShortcut: store.editingCategory?.shortcut.rawValue ?? "",
                directoryURL: store.selectedDirectoryURL
            ) { name, shortcut in
                if let editingCategory = store.editingCategory {
                    try store.updateCategory(id: editingCategory.id, name: name, shortcut: shortcut)
                } else {
                    try store.createCategory(name: name, shortcut: shortcut)
                }
            } onCancel: {
                store.dismissCategorySheet()
            }
        }
        .sheet(item: $editingPhoto) { photo in
            PhotoEditorSheet(photo: photo) { data, originalData in
                guard store.currentPhoto?.id == photo.id else { throw SessionError.noCurrentPhoto }
                try store.saveEditedPhoto(data: data, expectedCurrentData: originalData)
            }
        }
        .confirmationDialog("Delete Photo?", isPresented: Binding(
            get: { photoPendingDeletion != nil },
            set: { if !$0 { photoPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive) {
                guard let photo = photoPendingDeletion, store.currentPhoto?.id == photo.id else { return }
                store.perform { try store.deleteCurrentPhoto() }
                photoPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { photoPendingDeletion = nil }
        } message: {
            Text("Remove “\(photoPendingDeletion?.filename ?? "")” from this folder? You can undo this during the current session. A recovery copy is kept in PhotoSorter’s Application Support folder.")
        }
        .confirmationDialog("Use Folders as Categories?", isPresented: pendingProjectPromptIsPresented, titleVisibility: .visible) {
            Button("Use Existing Categories") { store.confirmPendingProjectOpen(asExistingProject: true) }
            Button("Only Photos in This Folder") { store.confirmPendingProjectOpen(asExistingProject: false) }
            Button("Cancel", role: .cancel) { store.dismissPendingProjectOpen() }
        } message: {
            if let pending = store.pendingProjectOpen {
                Text("“\(pending.directoryURL.lastPathComponent)” contains \(pending.existingCategoryCount) subfolders. Use them as categories, or open only the photos directly in this folder.")
            }
        }
        .alert(item: $store.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onChange(of: store.activeFeedback?.id) { _, _ in
            guard let feedback = store.activeFeedback else { return }
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: feedback.message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ])
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if notification.object is QLPreviewPanel {
                // Quick Look can hide its macOS panel without resetting SwiftUI's URL binding.
                previewURL = nil
            }
        }
        .onDisappear { previewURL = nil }
        .onChange(of: store.currentPhoto?.currentURL) { _, _ in
            previewURL = nil
        }
    }

    private var sessionCommandsEnabled: Bool {
        !store.isLoading && !store.isPresentingCategorySheet && store.activeAlert == nil
            && store.pendingProjectOpen == nil && previewURL == nil && !showsKeyboardHelp
            && editingPhoto == nil && photoPendingDeletion == nil
    }

    private func chooseFolder() {
        previewURL = nil
        guard let directoryURL = folderPicker.chooseDirectory() else { return }
        store.openDirectory(directoryURL)
    }

    private func categorizeCurrentPhoto(with categoryID: Category.ID) {
        guard store.canCategorizeCurrentPhoto else { return }
        store.perform { try store.categorizeCurrentPhoto(with: categoryID) }
    }

    private func handlePhotoAction(_ photoID: PhotoItem.ID, _ action: PhotoContextAction) {
        guard sessionCommandsEnabled,
              let index = store.photos.firstIndex(where: { $0.id == photoID }) else { return }
        store.selectPhoto(at: index)
        let photo = store.photos[index]
        switch action {
        case .edit:
            editingPhoto = photo
        case let .categorize(categoryID):
            if let categoryID {
                categorizeCurrentPhoto(with: categoryID)
            } else {
                store.perform { try store.removeCategoryFromCurrentPhoto() }
            }
        case .delete:
            photoPendingDeletion = photo
        case .copy:
            store.perform {
                guard FileManager.default.fileExists(atPath: photo.currentURL.path) else {
                    throw SessionError.sourceFileMissing(photo.filename)
                }
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.writeObjects([photo.currentURL as NSURL]) else {
                    throw SessionError.unexpected("The photo could not be copied to the clipboard.")
                }
                store.activeFeedback = SessionFeedback(message: "Copied \(photo.filename)", categoryID: nil, systemImage: "doc.on.doc")
                AppLogger.debug("Copied \(photo.filename) to the clipboard", category: .ui)
            }
        case .quickLook:
            previewURL = photo.currentURL
        case .showInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([photo.currentURL])
        }
    }

    private var pendingProjectPromptIsPresented: Binding<Bool> {
        Binding(
            get: { store.pendingProjectOpen != nil },
            set: { if !$0 { store.dismissPendingProjectOpen() } }
        )
    }
}

#Preview {
    ContentView(store: SortSessionStore())
}
