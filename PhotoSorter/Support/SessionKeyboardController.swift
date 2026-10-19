//
//  PhotoSorter
//

import AppKit
import Foundation

@MainActor
struct SessionKeyboardController {
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let deleteKeyCode: UInt16 = 51

    func handle(_ event: NSEvent, store: SortSessionStore) -> Bool {
        guard !store.isPresentingCategorySheet,
              store.activeAlert == nil,
              store.pendingProjectOpen == nil,
              !store.isLoading else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let effectiveModifiers = modifiers.subtracting([.function, .numericPad])

        if effectiveModifiers == [.command], let characters = normalizedCharacters(in: event) {
            switch characters {
            case "n":
                guard !event.isARepeat else { return true }
                store.openCategorySheet()
                return true
            case "z":
                guard !event.isARepeat else { return true }
                guard store.canUndo else { return false }
                store.perform {
                    try store.undoLastAction()
                }
                return true
            default:
                break
            }
        }

        switch event.keyCode {
        case Self.leftArrowKeyCode where effectiveModifiers.isEmpty:
            store.previousPhoto()
            return true
        case Self.rightArrowKeyCode where effectiveModifiers.isEmpty:
            store.nextPhoto()
            return true
        case Self.deleteKeyCode where effectiveModifiers.isEmpty:
            guard !event.isARepeat else { return true }
            guard store.canRemoveCurrentPhotoCategory else { return false }
            store.perform {
                try store.removeCategoryFromCurrentPhoto()
            }
            return true
        default:
            break
        }

        guard effectiveModifiers.isEmpty else { return false }
        guard let characters = normalizedCharacters(in: event) else { return false }
        guard let key = ShortcutKey(characters) else { return false }
        guard let category = store.categories.first(where: { $0.shortcut == key }) else { return false }
        guard !event.isARepeat else { return true }
        guard store.canCategorizeCurrentPhoto else { return false }

        store.perform {
            try store.categorizeCurrentPhoto(with: category.id)
        }
        return true
    }

    private func normalizedCharacters(in event: NSEvent) -> String? {
        event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
