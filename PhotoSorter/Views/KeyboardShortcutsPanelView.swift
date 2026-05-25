//
//  PhotoSorter
//

import SwiftUI

struct KeyboardShortcutsPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.headline)

            shortcutRow(key: "←", action: "Previous photo")
            shortcutRow(key: "→", action: "Next photo")
            shortcutRow(key: "⌫", action: "Remove category")
            shortcutRow(key: "⌘N", action: "New category")
            shortcutRow(key: "⌘Z", action: "Undo last move")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func shortcutRow(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .font(.headline.monospaced())
                .frame(width: 44)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(action)
                .foregroundStyle(.secondary)
        }
    }
}
