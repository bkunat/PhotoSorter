//
//  PhotoSorter
//

import Foundation

nonisolated struct Category: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var shortcut: ShortcutKey
    var destinationFolderURL: URL

    init(
        id: UUID = UUID(),
        name: String,
        shortcut: ShortcutKey,
        destinationFolderURL: URL
    ) {
        self.id = id
        self.name = name
        self.shortcut = shortcut
        self.destinationFolderURL = destinationFolderURL
    }
}
