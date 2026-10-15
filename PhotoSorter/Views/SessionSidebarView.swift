//
//  PhotoSorter
//

import SwiftUI

struct SessionSidebarView: View {
    let directoryURL: URL?
    let categories: [Category]
    let stats: SessionStats
    let currentCategoryID: Category.ID?
    let canCreateCategories: Bool
    let canCategorizeCurrentPhoto: Bool
    let onAddCategory: () -> Void
    let onEditCategory: (Category.ID?) -> Void
    let onCategorize: (Category.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let directoryURL {
                Label(directoryURL.lastPathComponent, systemImage: "folder.fill")
                    .font(.headline)
                    .lineLimit(2)
                    .help(directoryURL.path)
                CategoryListPanelView(
                    categories: categories,
                    stats: stats,
                    currentCategoryID: currentCategoryID,
                    canCreateCategories: canCreateCategories,
                    canCategorizeCurrentPhoto: canCategorizeCurrentPhoto,
                    onAddCategory: onAddCategory,
                    onEditCategory: onEditCategory,
                    onCategorize: onCategorize
                )
            } else {
                Label("Your categories", systemImage: "tag")
                    .font(.headline)
                Text("Choose a folder, then create a category for each destination.")
                    .foregroundStyle(.secondary)
                Text("Assign photos with a single letter or number key.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
