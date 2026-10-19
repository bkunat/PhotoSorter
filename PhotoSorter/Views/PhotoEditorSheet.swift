//
//  PhotoSorter
//

import AppKit
import SwiftUI

nonisolated private enum PhotoEditOperation: Sendable {
    case rotate
    case crop(CGRect)

    func apply(to image: CGImage) throws -> CGImage {
        switch self {
        case .rotate: try PhotoEditorImage.rotateClockwise(image)
        case let .crop(rect): try PhotoEditorImage.crop(image, normalizedRect: rect)
        }
    }
}

struct PhotoEditorSheet: View {
    let photo: PhotoItem
    let onSave: (Data, Data) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var originalData: Data?
    @State private var originalImage: CGImage?
    @State private var image: CGImage?
    @State private var edits: [PhotoEditOperation] = []
    @State private var isCropping = false
    @State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var isBusy = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit Photo").font(.title2.weight(.semibold))
                Text(photo.filename).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
            }

            HStack {
                Button("Rotate", systemImage: "rotate.right") { render(edits + [.rotate]) }
                    .help("Rotate 90 degrees clockwise")
                    .disabled(image == nil || isCropping)
                Button("Crop", systemImage: "crop") {
                    cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                    isCropping = true
                }
                .disabled(image == nil || isCropping)
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    if isCropping { isCropping = false } else { render(Array(edits.dropLast())) }
                }
                .keyboardShortcut("z")
                .disabled(edits.isEmpty && !isCropping)
                Spacer()
                if let image {
                    Text("\(image.width) × \(image.height)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .disabled(isBusy)

            GeometryReader { geometry in
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if let image {
                        let scale = min(geometry.size.width / CGFloat(image.width), geometry.size.height / CGFloat(image.height))
                        Image(image, scale: 1, label: Text("Photo being edited: \(photo.filename)"))
                            .resizable()
                            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                            .overlay {
                                if isCropping {
                                    CropSelectionView(rect: $cropRect)
                                }
                            }
                    } else if !isBusy {
                        ContentUnavailableView("Cannot Edit Photo", systemImage: "photo.badge.exclamationmark")
                    }
                    if isBusy { ProgressView("Processing photo…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(!isBusy)

            if isCropping {
                Text("Drag across the photo to select the area to keep, or adjust the controls below.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    cropControl("Left", keyPath: \.origin.x)
                    cropControl("Top", keyPath: \.origin.y)
                    cropControl("Width", keyPath: \.size.width)
                    cropControl("Height", keyPath: \.size.height)
                }
                HStack {
                    Spacer()
                    Button("Cancel Crop") { isCropping = false }
                    Button("Apply Crop") {
                        isCropping = false
                        render(edits + [.crop(cropRect)])
                    }
                    .disabled(cropRect.width <= 0 || cropRect.height <= 0)
                }
                .disabled(isBusy)
            }

            Text("Save updates this file. Originals are kept in PhotoSorter’s Application Support folder. You can undo saved edits during this sorting session.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(edits.isEmpty || isCropping || image == nil)
            }
            .disabled(isBusy)
        }
        .padding(24)
        .frame(minWidth: 700, idealWidth: 850, minHeight: 560, idealHeight: 700)
        .interactiveDismissDisabled(isBusy || !edits.isEmpty)
        .task {
            let url = photo.currentURL
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let data = try Data(contentsOf: url)
                    return (data, try PhotoEditorImage.load(from: url))
                }.value
                originalData = result.0
                originalImage = result.1
                image = result.1
                AppLogger.info("Opened editor for \(photo.filename)", category: .ui)
            } catch { showError(error) }
            isBusy = false
        }
        .alert("Unable to Edit Photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func cropControl(_ title: String, keyPath: WritableKeyPath<CGRect, CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(Int((cropRect[keyPath: keyPath] * 100).rounded()))%")
                .font(.caption.monospacedDigit())
            Slider(value: Binding(
                get: { cropRect[keyPath: keyPath] },
                set: { value in
                    var rect = cropRect
                    rect[keyPath: keyPath] = value
                    let minimumWidth = 1 / CGFloat(image?.width ?? 1)
                    let minimumHeight = 1 / CGFloat(image?.height ?? 1)
                    rect.origin.x = min(rect.origin.x, 1 - minimumWidth)
                    rect.origin.y = min(rect.origin.y, 1 - minimumHeight)
                    rect.size.width = max(minimumWidth, min(rect.width, 1 - rect.minX))
                    rect.size.height = max(minimumHeight, min(rect.height, 1 - rect.minY))
                    cropRect = rect
                }
            ), in: 0...1)
            .accessibilityLabel(title)
            .accessibilityValue("\(Int((cropRect[keyPath: keyPath] * 100).rounded())) percent")
        }
        .disabled(isBusy)
    }

    private func render(_ nextEdits: [PhotoEditOperation]) {
        guard let originalImage else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                image = try await Task.detached(priority: .userInitiated) {
                    try nextEdits.reduce(originalImage) { try $1.apply(to: $0) }
                }.value
                edits = nextEdits
            } catch { showError(error) }
        }
    }

    private func save() {
        guard let image, let originalData else { return }
        isBusy = true
        let url = photo.currentURL
        Task {
            defer { isBusy = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try PhotoEditorImage.encode(image, preservingSourceAt: url)
                }.value
                try onSave(data, originalData)
                dismiss()
            } catch { showError(error) }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        AppLogger.error("Editor failed for \(photo.filename): \(error.localizedDescription)", category: .ui)
    }
}

private struct CropSelectionView: View {
    @Binding var rect: CGRect

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
                Rectangle().stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                let startX = max(0, min(1, value.startLocation.x / geometry.size.width))
                let startY = max(0, min(1, value.startLocation.y / geometry.size.height))
                let endX = max(0, min(1, value.location.x / geometry.size.width))
                let endY = max(0, min(1, value.location.y / geometry.size.height))
                rect = CGRect(x: min(startX, endX), y: min(startY, endY), width: abs(endX - startX), height: abs(endY - startY))
            })
            .accessibilityHidden(true)
        }
    }
}
