//
//  PhotoSorter
//

import AppKit
import XCTest
@testable import PhotoSorter

@MainActor
final class SessionKeyboardControllerTests: XCTestCase {
    private let controller = SessionKeyboardController()

    func testCommandNOpensCategorySheetWhenFolderIsLoaded() throws {
        let store = try loadedStoreWithCategory()

        let handled = controller.handle(keyEvent(characters: "n", modifiers: [.command]), store: store)

        XCTAssertTrue(handled)
        XCTAssertTrue(store.isPresentingCategorySheet)
    }

    func testCommandZInvokesUndoOnlyWhenCanUndo() throws {
        let store = try loadedStoreWithCategory()
        let category = try XCTUnwrap(store.categories.first)

        XCTAssertFalse(controller.handle(keyEvent(characters: "z", modifiers: [.command]), store: store))

        try store.categorizeCurrentPhoto(with: category.id)
        XCTAssertTrue(controller.handle(keyEvent(characters: "z", modifiers: [.command]), store: store))
        XCTAssertTrue(store.undoHistory.isEmpty)
        XCTAssertEqual(store.photos.first?.status, .uncategorized)
    }

    func testLeftAndRightArrowsMoveSelection() throws {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        createFile(named: "b.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)

        XCTAssertTrue(controller.handle(keyEvent(characters: "", keyCode: 124), store: store))
        XCTAssertEqual(store.currentPhotoIndex, 1)
        XCTAssertTrue(controller.handle(keyEvent(characters: "", keyCode: 123), store: store))
        XCTAssertEqual(store.currentPhotoIndex, 0)
    }

    func testDeleteRemovesCurrentCategoryOnlyWhenCurrentPhotoIsCategorized() throws {
        let store = try loadedStoreWithCategory()
        let category = try XCTUnwrap(store.categories.first)

        XCTAssertFalse(controller.handle(keyEvent(characters: "\u{7F}", keyCode: 51), store: store))

        try store.categorizeCurrentPhoto(with: category.id)
        XCTAssertTrue(controller.handle(keyEvent(characters: "\u{7F}", keyCode: 51), store: store))
        XCTAssertEqual(store.photos.first?.status, .uncategorized)
    }

    func testBareCategoryShortcutCategorizesCurrentPhoto() throws {
        let store = try loadedStoreWithCategory()
        let category = try XCTUnwrap(store.categories.first)

        XCTAssertTrue(controller.handle(keyEvent(characters: "d"), store: store))

        XCTAssertEqual(store.photos.first?.status, .categorized(category.id))
    }

    func testShortcutsAreIgnoredWhileCategorySheetIsPresented() throws {
        let store = try loadedStoreWithCategory()
        store.isPresentingCategorySheet = true

        XCTAssertFalse(controller.handle(keyEvent(characters: "d"), store: store))
        XCTAssertEqual(store.photos.first?.status, .uncategorized)
    }

    func testModifiedCategoryKeysAreIgnoredExceptSupportedCommandShortcuts() throws {
        let store = try loadedStoreWithCategory()

        XCTAssertFalse(controller.handle(keyEvent(characters: "d", modifiers: [.shift]), store: store))
        XCTAssertFalse(controller.handle(keyEvent(characters: "d", modifiers: [.option]), store: store))
        XCTAssertTrue(controller.handle(keyEvent(characters: "n", modifiers: [.command]), store: store))
    }

    private func loadedStoreWithCategory() throws -> SortSessionStore {
        let directoryURL = try makeTemporaryDirectory()
        createFile(named: "a.jpg", in: directoryURL)
        let store = makeStore()
        try store.loadSession(from: directoryURL)
        try store.createCategory(name: "Dogs", shortcut: "d")
        return store
    }

    private func keyEvent(
        characters: String,
        modifiers: NSEvent.ModifierFlags = [],
        keyCode: UInt16 = 0
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}
