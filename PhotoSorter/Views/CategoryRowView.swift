//
//  PhotoSorter
//

import SwiftUI

struct CategoryRowView: View {
    let category: Category
    let assignedCount: Int
    let canCategorizeCurrentPhoto: Bool
    let isComplete: Bool
    let onEdit: () -> Void
    let onCategorize: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                guard canCategorizeCurrentPhoto else { return }
                onCategorize()
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: 10, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .foregroundStyle(.primary)

                        Text(category.destinationFolderURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(category.shortcut.displayValue)
                            .font(.headline.monospaced())
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.18))
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.36), lineWidth: 1)
                            }
                            .clipShape(Capsule())

                        Text("\(assignedCount) photo\(assignedCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .opacity(canCategorizeCurrentPhoto ? 1 : 0.78)
            .help(actionHelp)
            .accessibilityHint(actionHelp)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Edit category")
        }
        .contextMenu {
            Button("Edit Category", systemImage: "pencil") {
                onEdit()
            }
        }
    }

    private var actionHelp: String {
        if canCategorizeCurrentPhoto {
            return "Move current photo to \(category.name)"
        }

        if isComplete {
            return "\(category.name) has \(assignedCount) sorted photos"
        }

        return "Navigate to an uncategorized photo before assigning \(category.name)"
    }

    private var tint: Color {
        Color(nsColor: CategoryColorPalette.color(for: category))
    }
}
