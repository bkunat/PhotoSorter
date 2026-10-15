//
//  PhotoSorter
//

import SwiftUI

@main
struct PhotoSorterApp: App {
    @FocusedValue(\.sessionCommandsEnabled) private var sessionCommandsEnabled
    @State private var store = SortSessionStore()
    private let folderPicker = FolderPicker()

    init() {
        AppLogger.info("PhotoSorter launched", category: .app)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Session") {
                Button("Choose Folder") {
                    if let directoryURL = folderPicker.chooseDirectory() {
                        store.openDirectory(directoryURL)
                    }
                }
                .keyboardShortcut("o")
                .disabled(sessionCommandsEnabled != true)

                Button("New Category") {
                    store.openCategorySheet()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(!store.canCreateCategories || sessionCommandsEnabled != true)

                Button("Undo Last Move") {
                    store.perform {
                        try store.undoLastCategorization()
                    }
                }
                .keyboardShortcut("z")
                .disabled(!store.canUndo || sessionCommandsEnabled != true)
            }
        }
    }
}
