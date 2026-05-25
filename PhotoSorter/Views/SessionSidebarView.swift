//
//  PhotoSorter
//

import SwiftUI

struct SessionSidebarView: View {
    let directoryURL: URL?
    let categories: [Category]
    let stats: SessionStats
    let canCreateCategories: Bool
    let canCategorizeCurrentPhoto: Bool
    let onAddCategory: () -> Void
    let onEditCategory: (Category.ID?) -> Void
    let onCategorize: (Category.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SessionPanelView(
                directoryURL: directoryURL,
                categories: categories,
                stats: stats
            )
            CategoryListPanelView(
                categories: categories,
                stats: stats,
                canCreateCategories: canCreateCategories,
                canCategorizeCurrentPhoto: canCategorizeCurrentPhoto,
                onAddCategory: onAddCategory,
                onEditCategory: onEditCategory,
                onCategorize: onCategorize
            )
            KeyboardShortcutsPanelView()
        }
    }
}
