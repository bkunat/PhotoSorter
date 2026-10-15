//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct SorterWorkspaceView: View {
    let directoryURL: URL
    let photos: [PhotoItem]
    let categories: [Category]
    let stats: SessionStats
    let currentPhotoIndex: Int?
    let activeFeedback: SessionFeedback?
    let onSelectPhoto: (Int) -> Void
    let onChooseAnotherFolder: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PhotoCarouselView(
                photos: photos,
                categoriesByID: stats.categoriesByID,
                currentPhotoIndex: currentPhotoIndex,
                onSelectPhoto: onSelectPhoto
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if stats.isComplete {
                        Label("All photos sorted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Show Folder in Finder") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directoryURL.path)
                        }
                        Button("Choose Another Folder", action: onChooseAnotherFolder)
                    } else {
                        Text("\(stats.sortedCount) of \(stats.totalCount) sorted")
                        ProgressView(value: stats.progress)
                            .frame(maxWidth: 180)
                            .accessibilityLabel("Sorting progress")
                            .accessibilityValue("\(stats.progressPercent) percent complete")
                        Spacer()
                        Text("\(stats.remainingCount) remaining")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .monospacedDigit()
                HStack(spacing: 6) {
                    if let activeFeedback {
                        Image(systemName: activeFeedback.systemImage)
                            .accessibilityHidden(true)
                        Text(activeFeedback.message)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(categories.isEmpty ? "Add a category to start sorting." : "Press a category key to move this photo. Space opens Quick Look.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 18, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
