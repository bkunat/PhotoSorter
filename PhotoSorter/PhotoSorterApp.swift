//
//  PhotoSorter
//

import SwiftUI

@main
struct PhotoSorterApp: App {
    @State private var store = SortSessionStore()
    private let folderPicker = FolderPicker()

    init() {
        AppLogger.info("PhotoSorter launched", category: .app)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .commands {
            CommandMenu("Session") {
                Button("Choose Folder") {
                    if let directoryURL = folderPicker.chooseDirectory() {
                        store.openDirectory(directoryURL)
                    }
                }
                .keyboardShortcut("o")

                Button("New Category") {
                    store.openCategorySheet()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(!store.canCreateCategories)

                Button("Undo Categorization") {
                    store.perform {
                        try store.undoLastCategorization()
                    }
                }
                .keyboardShortcut("z")
                .disabled(!store.canUndo)
            }
        }
    }
}
