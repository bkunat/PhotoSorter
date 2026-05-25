//
//  PhotoSorter
//

import SwiftUI

struct StatusBadgeView: View {
    let isComplete: Bool
    let currentPhotoCategory: Category?

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.16))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private var title: String {
        if isComplete {
            return "Completed"
        }

        if let currentPhotoCategory {
            return currentPhotoCategory.name
        }

        return "Unsorted"
    }

    private var systemImage: String {
        if isComplete {
            return "checkmark.circle.fill"
        }

        if currentPhotoCategory != nil {
            return "folder.fill.badge.person.crop"
        }

        return "circle.dashed"
    }

    private var tint: Color {
        if isComplete {
            return .green
        }

        if let currentPhotoCategory {
            return Color(nsColor: CategoryColorPalette.color(for: currentPhotoCategory))
        }

        return .orange
    }
}
