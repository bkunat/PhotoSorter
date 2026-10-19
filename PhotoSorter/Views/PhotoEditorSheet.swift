//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct PhotoEditorSheet: View {
    let photo: PhotoItem
    let onSave: (Data, Data) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var originalData: Data?
    @State private var image: CGImage?
    @State private var editor = PhotoEditorState()
    @State private var isBusy = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit").font(.title2.weight(.semibold))
                Text(photo.filename).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { editor.undo() }
                    .keyboardShortcut("z")
                    .disabled(!editor.canUndo || isBusy)
            }

            HStack(spacing: 12) {
                Button("Rotate 90°", systemImage: "rotate.right") { editor.rotateClockwise() }
                    .help("Rotate 90 degrees clockwise")
                Label("Rotate", systemImage: "dial.low")
                Slider(value: Binding(
                    get: { editor.adjustments.angle },
                    set: { editor.setAngle($0) }
                ), in: -45...45, onEditingChanged: adjustmentEditingChanged)
                .accessibilityLabel("Fine rotation")
                .accessibilityValue("\(editor.adjustments.angle.formatted(.number.precision(.fractionLength(1)))) degrees")
                TextField("Degrees", value: Binding(
                    get: { editor.adjustments.angle },
                    set: { editor.setAngle($0) }
                ), format: .number.precision(.fractionLength(1)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 58)
                .accessibilityLabel("Rotation angle in degrees")
                Text("°").foregroundStyle(.secondary)
            }
            .disabled(isBusy || image == nil)

            GeometryReader { geometry in
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if let image {
                        let size = rotatedSize(of: image)
                        let fit = min(geometry.size.width / size.width, geometry.size.height / size.height)
                        Image(image, scale: 1, label: Text("Photo being edited: \(photo.filename)"))
                            .resizable()
                            .frame(width: CGFloat(image.width) * fit, height: CGFloat(image.height) * fit)
                            .rotationEffect(.degrees(Double(editor.adjustments.quarterTurns) * 90 + editor.adjustments.angle))
                            .scaleEffect(PhotoEditorImage.straightenScale(size: size, degrees: editor.adjustments.angle))
                            .frame(width: size.width * fit, height: size.height * fit)
                            .clipped()
                            .overlay {
                                CropSelectionView(
                                    rect: editor.adjustments.cropRect,
                                    onChange: { editor.setCropRect($0) },
                                    onBegin: { editor.beginAdjustment() },
                                    onEnd: { editor.endAdjustment() }
                                )
                            }
                    } else if !isBusy {
                        ContentUnavailableView("Cannot Edit", systemImage: "photo.badge.exclamationmark")
                    }
                    if isBusy { ProgressView("Processing photo…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(!isBusy)

            HStack {
                Label("Crop", systemImage: "crop").font(.headline)
                Text("Drag the corners to resize. Drag inside the frame to move it.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Reset Crop") { editor.setCropRect(PhotoEditorAdjustments().cropRect) }
                    .disabled(editor.adjustments.cropRect == PhotoEditorAdjustments().cropRect)
            }
            .disabled(isBusy || image == nil)

            Text("Save updates this file. Originals are kept in PhotoSorter’s Application Support folder. You can undo saved edits during this sorting session.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.hasChanges || image == nil)
            }
            .disabled(isBusy)
        }
        .padding(24)
        .frame(minWidth: 700, idealWidth: 850, minHeight: 600, idealHeight: 700)
        .interactiveDismissDisabled(isBusy || editor.hasChanges)
        .task {
            let url = photo.currentURL
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let data = try Data(contentsOf: url)
                    return (data, try PhotoEditorImage.load(from: url))
                }.value
                originalData = result.0
                image = result.1
                AppLogger.info("Opened editor for \(photo.filename)", category: .ui)
            } catch { showError(error) }
            isBusy = false
        }
        .alert("Unable to Edit", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func rotatedSize(of image: CGImage) -> CGSize {
        editor.adjustments.quarterTurns.isMultiple(of: 2)
            ? CGSize(width: image.width, height: image.height)
            : CGSize(width: image.height, height: image.width)
    }

    private func adjustmentEditingChanged(_ isEditing: Bool) {
        if isEditing { editor.beginAdjustment() } else { editor.endAdjustment() }
    }

    private func save() {
        guard let image, let originalData else { return }
        editor.endAdjustment()
        let adjustments = editor.adjustments
        isBusy = true
        let url = photo.currentURL
        Task {
            defer { isBusy = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    var result = image
                    for _ in 0..<adjustments.quarterTurns {
                        result = try PhotoEditorImage.rotateClockwise(result)
                    }
                    result = try PhotoEditorImage.straighten(result, degrees: adjustments.angle)
                    result = try PhotoEditorImage.crop(result, normalizedRect: adjustments.cropRect)
                    return try PhotoEditorImage.encode(result, preservingSourceAt: url)
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
