//
//  PhotoSorter
//

import AppKit
import Foundation

@MainActor
struct FolderPicker {
    func chooseDirectory() -> URL? {
        AppLogger.info("Presenting folder picker", category: .ui)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose a folder containing the photos you want to sort."

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            AppLogger.debug("Folder picker cancelled", category: .ui)
            return nil
        }

        AppLogger.info("Folder selected: \(directoryURL.path)", category: .session)
        return directoryURL
    }
}
