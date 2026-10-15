//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct CategoryEditorSheet: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                "New Category"
            case .edit:
                "Edit Category"
            }
        }

        var description: String {
            switch self {
            case .create:
                "Create a category with a single unmodified shortcut key."
            case .edit:
                "Renaming a category also renames its folder. Your photos stay inside it."
            }
        }
    }

    private enum Field {
        case name
        case shortcut
    }

    private static let returnKeyCode: UInt16 = 36
    private static let enterKeyCode: UInt16 = 76

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var shortcut: String
    @State private var suggestedShortcut: String
    @State private var hasCustomizedShortcut: Bool
    @State private var validationMessage: String?
    @State private var keyMonitor: Any?
    @FocusState private var focusedField: Field?

    let mode: Mode
    let directoryURL: URL?
    let onSave: (String, String) throws -> Void
    let onCancel: () -> Void

    init(
        mode: Mode,
        initialName: String = "",
        initialShortcut: String = "",
        directoryURL: URL? = nil,
        onSave: @escaping (String, String) throws -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.directoryURL = directoryURL
        self.onSave = onSave
        self.onCancel = onCancel

        let normalizedShortcut = initialShortcut.lowercased()

        _name = State(initialValue: initialName)
        _shortcut = State(initialValue: normalizedShortcut)
        _suggestedShortcut = State(initialValue: Self.sanitizeShortcut(initialName))
        _hasCustomizedShortcut = State(initialValue: false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mode.title)
                .font(.title2.weight(.semibold))

            Text(mode.description)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category Name")
                    .font(.headline)

                TextField("Dog", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onChange(of: name) { _, newValue in
                        updateSuggestedShortcut(for: newValue)
                    }
                    .onSubmit {
                        focusedField = .shortcut
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcut")
                    .font(.headline)

                TextField(
                    "D",
                    text: Binding(
                        get: { shortcut.uppercased() },
                        set: { updateShortcut(from: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .shortcut)
                .onSubmit(save)

                Text("Letters and digits only. The first letter of the category is suggested automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let directoryURL {
                Text("Destination: " + directoryURL.appendingPathComponent(name.trimmingCharacters(in: .whitespacesAndNewlines)).path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(mode == .create ? "Save" : "Apply") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            hasCustomizedShortcut = !shortcut.isEmpty && shortcut != suggestedShortcut
            focusedField = .name
            installKeyMonitor()
        }
        .onDisappear(perform: removeKeyMonitor)
    }

    private func save() {
        do {
            try onSave(name, shortcut)
            dismiss()
        } catch let error as LocalizedError {
            validationMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private static func sanitizeShortcut(_ value: String) -> String {
        let allowedScalars = value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        guard let firstScalar = allowedScalars.first else {
            return ""
        }

        return String(firstScalar).lowercased()
    }

    private func updateSuggestedShortcut(for newName: String) {
        let nextSuggestion = Self.sanitizeShortcut(newName)
        let shouldApplySuggestion = !hasCustomizedShortcut || shortcut.isEmpty || shortcut == suggestedShortcut

        validationMessage = nil
        suggestedShortcut = nextSuggestion

        guard shouldApplySuggestion else { return }
        shortcut = nextSuggestion
    }

    private func updateShortcut(from value: String) {
        let sanitizedShortcut = Self.sanitizeShortcut(value)
        validationMessage = nil
        shortcut = sanitizedShortcut
        hasCustomizedShortcut = !sanitizedShortcut.isEmpty && sanitizedShortcut != suggestedShortcut
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let effectiveModifiers = modifiers.subtracting([.function, .numericPad])

            guard effectiveModifiers == [.command] else {
                return event
            }

            guard event.keyCode == Self.returnKeyCode || event.keyCode == Self.enterKeyCode else {
                return event
            }

            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return event
            }

            save()
            return nil
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }

        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}
