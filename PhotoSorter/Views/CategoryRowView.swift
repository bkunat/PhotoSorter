//
//  PhotoSorter
//

import SwiftUI

struct CategoryRowView: View {
    let category: Category
    let assignedCount: Int
    let canCategorizeCurrentPhoto: Bool
    let isCurrentCategory: Bool
    let onEdit: () -> Void
    let onCategorize: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCategorize) {
                HStack(spacing: 10) {
                    Image(systemName: isCurrentCategory ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(tint)
                        .font(.system(size: isCurrentCategory ? 16 : 10))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .font(.body.weight(isCurrentCategory ? .semibold : .regular))
                            .lineLimit(2)
                        Text("\(assignedCount) photo\(assignedCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 4)
                    Text(category.shortcut.displayValue)
                        .font(.callout.monospaced().weight(.medium))
                        .frame(minWidth: 24, minHeight: 25)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                }
                .contentShape(Rectangle())
                .padding(.vertical, 9)
                .padding(.leading, 8)
            }
            .buttonStyle(.plain)
            .disabled(!canCategorizeCurrentPhoto || isCurrentCategory)
            .help(isCurrentCategory ? "Current category" : "Move current photo to \(category.name)")
            .accessibilityLabel("\(category.name), \(assignedCount) photo\(assignedCount == 1 ? "" : "s"), shortcut \(category.shortcut.displayValue)")
            .accessibilityValue(isCurrentCategory ? "Current category" : "")

            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(category.name)")
            .help("Edit \(category.name)")
        }
        .padding(.trailing, 4)
        .background(isCurrentCategory ? tint.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("Edit Category", systemImage: "pencil", action: onEdit)
        }
    }

    private var tint: Color {
        Color(nsColor: CategoryColorPalette.color(for: category))
    }
}
