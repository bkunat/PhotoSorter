//
//  PhotoSorter
//

import SwiftUI

struct SessionPanelView: View {
    let directoryURL: URL?
    let categories: [Category]
    let stats: SessionStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Session", systemImage: "sparkle.magnifyingglass")
                .font(.headline)

            if let directoryURL {
                Text(directoryURL.lastPathComponent)
                    .font(.title3.weight(.semibold))

                Text(directoryURL.path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)

                Divider()

                ProgressSummaryView(
                    sortedCount: stats.sortedCount,
                    totalCount: stats.totalCount,
                    remainingCount: stats.remainingCount,
                    progress: stats.progress,
                    progressPercent: stats.progressPercent,
                    showsStatRows: true
                )

                if !categories.isEmpty {
                    Divider()

                    CategoryDistributionView(
                        categoryCounts: stats.categoryCounts,
                        totalPhotoCount: stats.totalCount
                    )
                }
            } else {
                Text("Choose a folder to start a temporary sorting session.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
