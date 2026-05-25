//
//  PhotoSorter
//

import SwiftUI

struct SessionMainContentView: View {
    let selectedDirectoryURL: URL?
    let photos: [PhotoItem]
    let categories: [Category]
    let stats: SessionStats
    let currentPhotoIndex: Int?
    let currentPhoto: PhotoItem?
    let currentPhotoCategory: Category?
    let activeFeedback: SessionFeedback?
    let recentDirectories: [RecentDirectory]
    let canUndo: Bool
    let onChooseFolder: () -> Void
    let onOpenRecentDirectory: (RecentDirectory) -> Void
    let onSelectPhoto: (Int) -> Void

    var body: some View {
        Group {
            if selectedDirectoryURL == nil {
                EmptySessionView(
                    recentDirectories: recentDirectories,
                    onChooseFolder: onChooseFolder,
                    onOpenRecentDirectory: onOpenRecentDirectory
                )
            } else if photos.isEmpty {
                EmptyFolderView(onChooseFolder: onChooseFolder)
            } else {
                SorterWorkspaceView(
                    photos: photos,
                    categories: categories,
                    stats: stats,
                    currentPhotoIndex: currentPhotoIndex,
                    currentPhoto: currentPhoto,
                    currentPhotoCategory: currentPhotoCategory,
                    activeFeedback: activeFeedback,
                    canUndo: canUndo,
                    onSelectPhoto: onSelectPhoto,
                    onChooseAnotherFolder: onChooseFolder
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
