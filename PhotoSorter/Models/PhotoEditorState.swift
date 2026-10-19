//
//  PhotoSorter
//

import CoreGraphics

nonisolated struct PhotoEditorAdjustments: Equatable, Sendable {
    var quarterTurns = 0
    var angle: Double = 0
    var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
}

nonisolated struct PhotoEditorState {
    private(set) var adjustments = PhotoEditorAdjustments()
    private(set) var undoHistory: [PhotoEditorAdjustments] = []
    private var isAdjusting = false

    var hasChanges: Bool { adjustments != PhotoEditorAdjustments() }
    var canUndo: Bool { !undoHistory.isEmpty }

    mutating func beginAdjustment() {
        guard !isAdjusting else { return }
        undoHistory.append(adjustments)
        isAdjusting = true
    }

    mutating func endAdjustment() {
        guard isAdjusting else { return }
        if undoHistory.last == adjustments {
            undoHistory.removeLast()
        }
        isAdjusting = false
    }

    mutating func setAngle(_ value: Double) {
        guard value.isFinite else { return }
        let angle = (min(45, max(-45, value)) * 10).rounded() / 10
        guard angle != adjustments.angle else { return }
        if !isAdjusting { undoHistory.append(adjustments) }
        adjustments.angle = angle
    }

    mutating func setCropRect(_ rect: CGRect) {
        guard rect != adjustments.cropRect else { return }
        if !isAdjusting { undoHistory.append(adjustments) }
        adjustments.cropRect = rect
    }

    mutating func rotateClockwise() {
        endAdjustment()
        undoHistory.append(adjustments)
        adjustments.quarterTurns = (adjustments.quarterTurns + 1) % 4
        let crop = adjustments.cropRect
        adjustments.cropRect = CGRect(x: 1 - crop.maxY, y: crop.minX, width: crop.height, height: crop.width)
    }

    mutating func undo() {
        endAdjustment()
        guard let previous = undoHistory.popLast() else { return }
        adjustments = previous
    }
}
