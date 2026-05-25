//
//  PhotoSorter
//

import SwiftUI

struct RecentDirectoryRowView: View {
    let recentDirectory: RecentDirectory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(recentDirectory.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recentDirectory.path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text("Last opened \(recentDirectory.lastOpenedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 16)

            Image(systemName: "arrow.up.forward.app")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
