//
//  PhotoSorter
//

import SwiftUI

struct RecentDirectoriesView: View {
    let recentDirectories: [RecentDirectory]
    let onOpenRecentDirectory: (RecentDirectory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recent Folders", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.headline)

            Text("Only folders that still exist remain here. Select one to reopen it without browsing again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(recentDirectories) { recentDirectory in
                Button {
                    onOpenRecentDirectory(recentDirectory)
                } label: {
                    RecentDirectoryRowView(recentDirectory: recentDirectory)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reopen \(recentDirectory.displayName)")
                .help(recentDirectory.path)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
