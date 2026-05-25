//
//  PhotoSorter
//

import SwiftUI

struct PhotoHeaderView: View {
    let stats: SessionStats
    let currentPhotoIndex: Int?
    let currentPhotoCategory: Category?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stats.isComplete ? "Review Sorted Photos" : "Active Sorting")
                    .font(.title2.weight(.semibold))

                Text("\(stats.sortedCount) of \(stats.totalCount) sorted, \(stats.progressPercent)% complete, Photo \(positionText), \(stats.remainingCount) remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(stats.isComplete ? "Review sorted photos with the arrow keys." : "The center card is active; progress updates as photos move into categories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            StatusBadgeView(
                isComplete: stats.isComplete,
                currentPhotoCategory: currentPhotoCategory
            )
        }
    }

    private var positionText: String {
        guard let currentPhotoIndex else { return "0 / \(stats.totalCount)" }
        return "\(currentPhotoIndex + 1) / \(stats.totalCount)"
    }
}
