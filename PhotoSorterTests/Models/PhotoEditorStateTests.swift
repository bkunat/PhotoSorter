//
//  PhotoSorter
//

import CoreGraphics
import XCTest
@testable import PhotoSorter

@MainActor
final class PhotoEditorStateTests: XCTestCase {
    func testContinuousAdjustmentHasOneUndoStep() {
        var state = PhotoEditorState()

        state.beginAdjustment()
        state.setAngle(2)
        state.beginAdjustment()
        state.setAngle(7.5)
        state.endAdjustment()

        XCTAssertEqual(state.undoHistory.count, 1)
        XCTAssertTrue(state.hasChanges)
        state.undo()
        XCTAssertEqual(state.adjustments.angle, 0)
        XCTAssertFalse(state.hasChanges)
        XCTAssertFalse(state.canUndo)
    }

    func testNoOpAdjustmentDoesNotAddUndoStep() {
        var state = PhotoEditorState()
        state.rotateClockwise()
        let previousHistory = state.undoHistory

        state.beginAdjustment()
        state.setAngle(3)
        state.setAngle(0)
        state.endAdjustment()
        state.endAdjustment()

        XCTAssertEqual(state.undoHistory, previousHistory)
    }

    func testSeparateAdjustmentsUndoIndividually() {
        var state = PhotoEditorState()
        state.beginAdjustment()
        state.setAngle(-4.5)
        state.endAdjustment()
        let beforeCrop = state.adjustments

        state.beginAdjustment()
        state.setCropRect(CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.6))
        state.endAdjustment()

        state.undo()
        XCTAssertEqual(state.adjustments, beforeCrop)
        XCTAssertTrue(state.canUndo)
        state.undo()
        XCTAssertEqual(state.adjustments, PhotoEditorAdjustments())
    }

    func testFourQuarterTurnsReturnToOriginalOrientation() {
        var state = PhotoEditorState()

        for _ in 0..<4 {
            state.rotateClockwise()
        }

        XCTAssertEqual(state.adjustments.quarterTurns, 0)
        XCTAssertFalse(state.hasChanges)
        state.undo()
        XCTAssertEqual(state.adjustments.quarterTurns, 3)
    }

    func testFourQuarterTurnsPreserveOriginalCrop() {
        var state = PhotoEditorState()
        let crop = CGRect(x: 0.125, y: 0.25, width: 0.5, height: 0.625)
        state.setCropRect(crop)

        for _ in 0..<4 {
            state.rotateClockwise()
        }

        XCTAssertEqual(state.adjustments.quarterTurns, 0)
        XCTAssertEqual(state.adjustments.cropRect, crop)
    }

    func testRotationMapsCropPreservesAngleAndCanUndoBoth() {
        var state = PhotoEditorState()
        state.beginAdjustment()
        state.setAngle(5.5)
        state.setCropRect(CGRect(x: 0.125, y: 0.25, width: 0.5, height: 0.625))
        state.endAdjustment()
        let beforeRotation = state.adjustments

        state.rotateClockwise()

        XCTAssertEqual(state.adjustments.quarterTurns, 1)
        XCTAssertEqual(state.adjustments.angle, 5.5)
        XCTAssertEqual(state.adjustments.cropRect, CGRect(x: 0.125, y: 0.125, width: 0.625, height: 0.5))
        state.undo()
        XCTAssertEqual(state.adjustments, beforeRotation)
    }

    func testUndoWithoutHistoryLeavesInitialState() {
        var state = PhotoEditorState()

        state.undo()

        XCTAssertEqual(state.adjustments, PhotoEditorAdjustments())
        XCTAssertFalse(state.canUndo)
    }

    func testSettersWithoutGestureRecordIndividualUndoSteps() {
        var state = PhotoEditorState()
        state.setAngle(1)
        state.setAngle(2)
        state.setAngle(2)
        state.setCropRect(CGRect(x: 0.1, y: 0, width: 0.9, height: 1))

        XCTAssertEqual(state.undoHistory.count, 3)
        state.undo()
        XCTAssertEqual(state.adjustments.angle, 2)
        XCTAssertEqual(state.adjustments.cropRect, PhotoEditorAdjustments().cropRect)
        state.undo()
        XCTAssertEqual(state.adjustments.angle, 1)
    }

    func testFineRotationClampsAndIgnoresNonfiniteValues() {
        var state = PhotoEditorState()
        state.setAngle(100)
        XCTAssertEqual(state.adjustments.angle, 45)
        state.setAngle(-100)
        XCTAssertEqual(state.adjustments.angle, -45)

        state.setAngle(.nan)
        state.setAngle(.infinity)
        state.setAngle(-.infinity)

        XCTAssertEqual(state.adjustments.angle, -45)
        XCTAssertEqual(state.undoHistory.count, 2)
    }

    func testFineRotationRoundsToTenthsAndSkipsEquivalentValues() {
        var state = PhotoEditorState()
        state.setAngle(3.14)
        XCTAssertEqual(state.adjustments.angle, 3.1)
        state.setAngle(3.12)
        XCTAssertEqual(state.undoHistory.count, 1)

        state.setAngle(-3.16)
        XCTAssertEqual(state.adjustments.angle, -3.2)
        state.undo()
        XCTAssertEqual(state.adjustments.angle, 3.1)
    }
}
