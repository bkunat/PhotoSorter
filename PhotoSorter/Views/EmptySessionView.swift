//
//  PhotoSorter
//

import SwiftUI

struct EmptySessionView: View {
    let recentDirectories: [RecentDirectory]
    let onChooseFolder: () -> Void
    let onOpenRecentDirectory: (RecentDirectory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ContentUnavailableView(
                    "Choose a Folder",
                    systemImage: "folder.badge.plus",
                    description: Text("Select a folder of top-level photos to start sorting.")
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    Button("Select Folder") {
                        onChooseFolder()
                    }
                    .buttonStyle(.borderedProminent)

                    if !recentDirectories.isEmpty {
                        Text("\(recentDirectories.count) recent folder\(recentDirectories.count == 1 ? "" : "s") available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !recentDirectories.isEmpty {
                    RecentDirectoriesView(
                        recentDirectories: recentDirectories,
                        onOpenRecentDirectory: onOpenRecentDirectory
                    )
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
