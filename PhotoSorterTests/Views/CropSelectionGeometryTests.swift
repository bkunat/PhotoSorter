//
//  PhotoSorter
//

import CoreGraphics
import XCTest
@testable import PhotoSorter

final class CropSelectionGeometryTests: XCTestCase {
    func testCornerResizeKeepsOppositeCornerAndClampsToImage() {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.5)
        let result = CropSelectionGeometry.resized(rect, corner: .topLeft, to: CGPoint(x: -1, y: -1))

        XCTAssertEqual(result.minX, 0)
        XCTAssertEqual(result.minY, 0)
        XCTAssertEqual(result.maxX, rect.maxX)
        XCTAssertEqual(result.maxY, rect.maxY)

        let bottomRight = CropSelectionGeometry.resized(rect, corner: .bottomRight, to: CGPoint(x: 2, y: 2))
        XCTAssertEqual(bottomRight.minX, rect.minX)
        XCTAssertEqual(bottomRight.minY, rect.minY)
        XCTAssertEqual(bottomRight.maxX, 1)
        XCTAssertEqual(bottomRight.maxY, 1)
    }

    func testCornerCannotCrossOppositeCorner() {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.5)
        for corner in CropSelectionGeometry.Corner.allCases {
            let point = CGPoint(x: corner.isLeft ? 2 : -1, y: corner.isTop ? 2 : -1)
            let result = CropSelectionGeometry.resized(rect, corner: corner, to: point)
            XCTAssertEqual(result.width, 0.01, accuracy: 0.000001)
            XCTAssertEqual(result.height, 0.01, accuracy: 0.000001)
            XCTAssertGreaterThanOrEqual(result.minX, 0)
            XCTAssertGreaterThanOrEqual(result.minY, 0)
            XCTAssertLessThanOrEqual(result.maxX, 1)
            XCTAssertLessThanOrEqual(result.maxY, 1)
        }
    }

    func testMovingPreservesSizeAndStopsAtImageBounds() {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.5)
        let result = CropSelectionGeometry.moved(rect, translation: CGSize(width: -2, height: 2))
        XCTAssertEqual(result, CGRect(x: 0, y: 0.5, width: 0.6, height: 0.5))
    }

    func testNewSelectionSupportsReverseDragAndClampsToImage() {
        let result = CropSelectionGeometry.selection(from: CGPoint(x: 0.8, y: 0.7), to: CGPoint(x: -1, y: -1))
        XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 0.8, height: 0.7))
    }

    func testNewSelectionAtImageEdgeHasMinimumSizeInsideImage() {
        let result = CropSelectionGeometry.selection(from: CGPoint(x: 1, y: 1), to: CGPoint(x: 1, y: 1))
        XCTAssertEqual(result, CGRect(x: 0.99, y: 0.99, width: 0.01, height: 0.01))
    }
}
