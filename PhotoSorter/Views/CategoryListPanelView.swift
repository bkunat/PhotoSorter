//
//  PhotoSorter
//

import SwiftUI

struct CategoryListPanelView: View {
    let categories: [Category]
    let stats: SessionStats
    let currentCategoryID: Category.ID?
    let canCreateCategories: Bool
    let canCategorizeCurrentPhoto: Bool
    let onAddCategory: () -> Void
    let onEditCategory: (Category.ID?) -> Void
    let onCategorize: (Category.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CATEGORIES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add", systemImage: "plus", action: onAddCategory)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(!canCreateCategories)
                    .help("Add a category (⌘N)")
            }
            .padding(.bottom, 4)

            if categories.isEmpty {
                Text("Add your first category to start sorting. Its shortcut moves the selected photo into that folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Add Category", action: onAddCategory)
                    .disabled(!canCreateCategories)
                    .padding(.top, 8)
            } else {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        assignedCount: stats.countByCategoryID[category.id, default: 0],
                        canCategorizeCurrentPhoto: canCategorizeCurrentPhoto,
                        isCurrentCategory: currentCategoryID == category.id,
                        onEdit: { onEditCategory(category.id) },
                        onCategorize: { onCategorize(category.id) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
