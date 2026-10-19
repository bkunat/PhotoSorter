//
//  PhotoSorter
//

import AppKit
import XCTest
@testable import PhotoSorter

@MainActor
final class PhotoCarouselContextMenuTests: XCTestCase {
    func testActionsTargetClickedPhotoInsteadOfSelectedPhoto() throws {
        let selected = PhotoItem(originalURL: URL(fileURLWithPath: "/selected.jpg"))
        let clicked = PhotoItem(originalURL: URL(fileURLWithPath: "/clicked.jpg"))
        let view = makeView(photos: [selected, clicked])
        var actions: [PhotoContextAction] = []
        view.onPhotoAction = { id, action in
            XCTAssertEqual(id, clicked.id)
            actions.append(action)
        }
        let menu = try XCTUnwrap(view.contextMenu(for: clicked.id))
        for title in ["Edit", "Quick Look", "Show in Finder", "Copy", "Delete Photo…"] {
            try activate(XCTUnwrap(menu.item(withTitle: title)))
        }
        XCTAssertEqual(actions, [.edit, .quickLook, .showInFinder, .copy, .delete])
    }

    func testCategoryMenuSortsAndChecksCurrentCategory() throws {
        let z = makeCategory("Zebra")
        let a = makeCategory("Apple")
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"), status: .categorized(z.id))
        let view = makeView(photos: [photo], categories: [z, a])
        let menu = try categoryMenu(view, photoID: photo.id)
        XCTAssertEqual(menu.items.map(\.title), ["Unsorted", "Apple", "Zebra"])
        XCTAssertEqual(menu.items.map(\.state), [.off, .off, .on])
        XCTAssertEqual(menu.items.map(\.isEnabled), [true, true, false])
        var actions: [PhotoContextAction] = []
        view.onPhotoAction = { id, action in
            XCTAssertEqual(id, photo.id)
            actions.append(action)
        }
        try activate(menu.items[0])
        try activate(menu.items[1])
        try activate(menu.items[2])
        XCTAssertEqual(actions, [.categorize(nil), .categorize(a.id)])
    }

    func testUnsortedPhotoChecksAndDisablesUnsorted() throws {
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"))
        let menu = try categoryMenu(makeView(photos: [photo]), photoID: photo.id)
        XCTAssertEqual(menu.items[0].state, .on)
        XCTAssertFalse(menu.items[0].isEnabled)
    }

    func testOpenMenuKeepsOriginalPhotoTargetWhenPhotosReorder() throws {
        let first = PhotoItem(originalURL: URL(fileURLWithPath: "/first.jpg"))
        let second = PhotoItem(originalURL: URL(fileURLWithPath: "/second.jpg"))
        let view = makeView(photos: [first, second])
        let menu = try XCTUnwrap(view.contextMenu(for: second.id))
        view.update(photos: [second, first], categoriesByID: [:], currentPhotoIndex: 1)
        var receivedID: PhotoItem.ID?
        view.onPhotoAction = { id, _ in receivedID = id }
        try activate(XCTUnwrap(menu.item(withTitle: "Delete Photo…")))
        XCTAssertEqual(receivedID, second.id)
    }

    func testRemovedPhotoCannotDispatchFromOpenMenu() throws {
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"))
        let replacement = PhotoItem(originalURL: photo.currentURL)
        let view = makeView(photos: [photo])
        let menu = try XCTUnwrap(view.contextMenu(for: photo.id))
        view.update(photos: [replacement], categoriesByID: [:], currentPhotoIndex: 0)
        view.onPhotoAction = { _, _ in XCTFail("Removed photo must not dispatch an action") }
        try activate(XCTUnwrap(menu.item(withTitle: "Copy")))
        XCTAssertNil(view.contextMenu(for: photo.id))
    }

    func testRemovedCategoryCannotDispatchFromOpenMenu() throws {
        let photo = PhotoItem(originalURL: URL(fileURLWithPath: "/photo.jpg"))
        let category = makeCategory("Category")
        let view = makeView(photos: [photo], categories: [category])
        let menu = try categoryMenu(view, photoID: photo.id)
        view.update(photos: [photo], categoriesByID: [:], currentPhotoIndex: 0)
        view.onPhotoAction = { _, _ in XCTFail("Removed category must not dispatch an action") }
        try activate(XCTUnwrap(menu.item(withTitle: category.name)))
    }

    func testReusedThumbnailClearsMenuAndKeepsOpenMenuTarget() throws {
        let first = PhotoItem(originalURL: URL(fileURLWithPath: "/first.jpg"))
        let second = PhotoItem(originalURL: URL(fileURLWithPath: "/second.jpg"))
        let view = makeView(photos: [first, second])
        let item = PhotoCarouselItem()
        item.onContextMenu = { view.contextMenu(for: first.id) }
        let oldMenu = try XCTUnwrap(item.onContextMenu?())
        item.prepareForReuse()
        XCTAssertNil(item.onContextMenu)
        item.onContextMenu = { view.contextMenu(for: second.id) }
        let newMenu = try XCTUnwrap(item.onContextMenu?())
        var receivedIDs: [PhotoItem.ID] = []
        view.onPhotoAction = { id, _ in receivedIDs.append(id) }
        try activate(XCTUnwrap(oldMenu.item(withTitle: "Edit")))
        try activate(XCTUnwrap(newMenu.item(withTitle: "Edit")))
        XCTAssertEqual(receivedIDs, [first.id, second.id])
    }

    func testAccessibilityShowMenuUsesDynamicProviderAndClearsOnReuse() throws {
        let item = PhotoCarouselItem()
        let button = try XCTUnwrap(item.view.subviews.compactMap { $0 as? NSButton }.first)
        var requests = 0
        item.onContextMenu = {
            requests += 1
            return nil
        }
        XCTAssertFalse(button.accessibilityPerformShowMenu())
        XCTAssertEqual(requests, 1)
        item.prepareForReuse()
        XCTAssertFalse(button.accessibilityPerformShowMenu())
        XCTAssertEqual(requests, 1)
    }

    private func makeView(photos: [PhotoItem], categories: [PhotoSorter.Category] = []) -> PhotoCarouselContainerView {
        let view = PhotoCarouselContainerView(previewLoader: PhotoCarouselPreviewLoader { _ in nil })
        view.update(photos: photos, categoriesByID: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }), currentPhotoIndex: 0)
        return view
    }

    private func makeCategory(_ name: String) -> PhotoSorter.Category {
        PhotoSorter.Category(name: name, shortcut: ShortcutKey("a")!, destinationFolderURL: URL(fileURLWithPath: "/\(name)"))
    }

    private func categoryMenu(_ view: PhotoCarouselContainerView, photoID: PhotoItem.ID) throws -> NSMenu {
        let menu = try XCTUnwrap(view.contextMenu(for: photoID))
        return try XCTUnwrap(menu.item(withTitle: "Change Category")?.submenu)
    }

    private func activate(_ item: NSMenuItem) throws {
        XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
    }
}
