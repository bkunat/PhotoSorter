//
//  PhotoSorter
//

import SwiftUI

struct CategoryListPanelView: View {
    let categories: [Category]
    let stats: SessionStats
    let canCreateCategories: Bool
    let canCategorizeCurrentPhoto: Bool
    let onAddCategory: () -> Void
    let onEditCategory: (Category.ID?) -> Void
    let onCategorize: (Category.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Categories", systemImage: "tag")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    onAddCategory()
                }
                .buttonStyle(.borderless)
                .disabled(!canCreateCategories)
            }

            if categories.isEmpty {
                Text("No categories yet. Press `Command-N` or use Add to create the first one.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        assignedCount: stats.countByCategoryID[category.id, default: 0],
                        canCategorizeCurrentPhoto: canCategorizeCurrentPhoto,
                        isComplete: stats.isComplete,
                        onEdit: { onEditCategory(category.id) },
                        onCategorize: { onCategorize(category.id) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
