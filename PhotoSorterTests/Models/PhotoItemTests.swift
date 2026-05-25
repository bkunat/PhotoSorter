//
//  PhotoSorter
//

import XCTest
@testable import PhotoSorter

final class PhotoItemTests: XCTestCase {
    func testInitializerDefaultsCurrentURLToOriginalURL() {
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")

        let item = PhotoItem(originalURL: url)

        XCTAssertEqual(item.currentURL, url)
    }

    func testInitializerDefaultsFilenameToOriginalLastPathComponent() {
        let item = PhotoItem(originalURL: URL(fileURLWithPath: "/tmp/Family Photo.JPG"))

        XCTAssertEqual(item.filename, "Family Photo.JPG")
    }

    func testPhotoStatusDerivedValues() {
        let categoryID = UUID()

        XCTAssertNil(PhotoStatus.uncategorized.assignedCategoryID)
        XCTAssertTrue(PhotoStatus.uncategorized.isUncategorized)
        XCTAssertEqual(PhotoStatus.categorized(categoryID).assignedCategoryID, categoryID)
        XCTAssertFalse(PhotoStatus.categorized(categoryID).isUncategorized)
    }
}
