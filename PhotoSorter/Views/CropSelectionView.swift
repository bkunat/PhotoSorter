//
//  PhotoSorter
//

import CoreGraphics
import SwiftUI

struct CropSelectionView: View {
    let rect: CGRect
    let onChange: (CGRect) -> Void
    let onBegin: () -> Void
    let onEnd: () -> Void

    @State private var dragStart: CGRect?
    @State private var dragAction: DragAction?

    private enum DragAction {
        case resize(CropSelectionGeometry.Corner)
        case move
        case create
    }

    var body: some View {
        GeometryReader { geometry in
            let selection = CGRect(x: rect.minX * geometry.size.width, y: rect.minY * geometry.size.height,
                                   width: rect.width * geometry.size.width, height: rect.height * geometry.size.height)
            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRect(selection)
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))

                Path { path in
                    path.addRect(selection)
                    for third in 1...2 {
                        let fraction = CGFloat(third) / 3
                        let x = selection.minX + selection.width * fraction
                        let y = selection.minY + selection.height * fraction
                        path.move(to: CGPoint(x: x, y: selection.minY))
                        path.addLine(to: CGPoint(x: x, y: selection.maxY))
                        path.move(to: CGPoint(x: selection.minX, y: y))
                        path.addLine(to: CGPoint(x: selection.maxX, y: y))
                    }
                }
                .stroke(.white.opacity(0.8), lineWidth: 1)

                Path { path in
                    for corner in CropSelectionGeometry.Corner.allCases {
                        let point = corner.point(in: selection)
                        let xLength = min(16, selection.width / 2) * (corner.isLeft ? 1 : -1)
                        let yLength = min(16, selection.height / 2) * (corner.isTop ? 1 : -1)
                        path.move(to: CGPoint(x: point.x + xLength, y: point.y))
                        path.addLine(to: point)
                        path.addLine(to: CGPoint(x: point.x, y: point.y + yLength))
                    }
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .square))
                .shadow(color: .black.opacity(0.6), radius: 1)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = rect
                        let closestCorner = CropSelectionGeometry.Corner.allCases.min {
                            distance($0.point(in: selection), value.startLocation)
                                < distance($1.point(in: selection), value.startLocation)
                        }!
                        if distance(closestCorner.point(in: selection), value.startLocation) <= 22 {
                            dragAction = .resize(closestCorner)
                        } else {
                            dragAction = selection.contains(value.startLocation) ? .move : .create
                        }
                        onBegin()
                    }
                    update(value, size: geometry.size)
                }
                .onEnded { value in
                    guard dragStart != nil else { return }
                    update(value, size: geometry.size)
                    dragStart = nil
                    dragAction = nil
                    onEnd()
                })
            .accessibilityHidden(true)
        }
    }

    private func distance(_ point: CGPoint, _ other: CGPoint) -> CGFloat {
        hypot(point.x - other.x, point.y - other.y)
    }

    private func update(_ value: DragGesture.Value, size: CGSize) {
        guard let dragStart, let dragAction, size.width > 0, size.height > 0 else { return }
        let point = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
        switch dragAction {
        case let .resize(corner):
            onChange(CropSelectionGeometry.resized(dragStart, corner: corner, to: point))
        case .move:
            let translation = CGSize(width: value.translation.width / size.width,
                                     height: value.translation.height / size.height)
            onChange(CropSelectionGeometry.moved(dragStart, translation: translation))
        case .create:
            let start = CGPoint(x: value.startLocation.x / size.width, y: value.startLocation.y / size.height)
            onChange(CropSelectionGeometry.selection(from: start, to: point))
        }
    }
}

nonisolated enum CropSelectionGeometry {
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var isLeft: Bool { self == .topLeft || self == .bottomLeft }
        var isTop: Bool { self == .topLeft || self == .topRight }

        func point(in rect: CGRect) -> CGPoint {
            CGPoint(x: isLeft ? rect.minX : rect.maxX, y: isTop ? rect.minY : rect.maxY)
        }
    }

    static func resized(_ rect: CGRect, corner: Corner, to point: CGPoint) -> CGRect {
        let left = corner.isLeft ? max(0, min(rect.maxX - 0.01, point.x)) : rect.minX
        let right = corner.isLeft ? rect.maxX : min(1, max(rect.minX + 0.01, point.x))
        let top = corner.isTop ? max(0, min(rect.maxY - 0.01, point.y)) : rect.minY
        let bottom = corner.isTop ? rect.maxY : min(1, max(rect.minY + 0.01, point.y))
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    static func moved(_ rect: CGRect, translation: CGSize) -> CGRect {
        CGRect(x: max(0, min(1 - rect.width, rect.minX + translation.width)),
               y: max(0, min(1 - rect.height, rect.minY + translation.height)),
               width: rect.width, height: rect.height)
    }

    static func selection(from start: CGPoint, to end: CGPoint) -> CGRect {
        let start = CGPoint(x: max(0, min(1, start.x)), y: max(0, min(1, start.y)))
        let end = CGPoint(x: max(0, min(1, end.x)), y: max(0, min(1, end.y)))
        let width = max(0.01, abs(end.x - start.x))
        let height = max(0.01, abs(end.y - start.y))
        return CGRect(x: min(1 - width, min(start.x, end.x)),
                      y: min(1 - height, min(start.y, end.y)), width: width, height: height)
    }
}
