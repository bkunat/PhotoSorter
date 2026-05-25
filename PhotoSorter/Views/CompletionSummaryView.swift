//
//  PhotoSorter
//

import SwiftUI

struct CompletionSummaryView: View {
    let sortedCount: Int
    let totalCount: Int
    let categoryCount: Int
    let progressPercent: Int
    let onChooseAnotherFolder: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sorting Complete")
                        .font(.headline)

                    Text("\(sortedCount) of \(totalCount) sorted, \(categoryCount) categories used, \(progressPercent)% complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)

                    Text("Use arrow keys to review.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 16)

            Button("Choose Another Folder", systemImage: "folder") {
                onChooseAnotherFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.green.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
