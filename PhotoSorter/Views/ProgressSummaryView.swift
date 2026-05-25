//
//  PhotoSorter
//

import SwiftUI

struct ProgressSummaryView: View {
    let sortedCount: Int
    let totalCount: Int
    let remainingCount: Int
    let progress: Double
    let progressPercent: Int
    let showsStatRows: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(progressPercent)%")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(sortedCount) of \(totalCount) sorted")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()

                    Text("\(remainingCount) remaining")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .accessibilityLabel("Sorting progress")
                .accessibilityValue("\(progressPercent) percent complete")

            if showsStatRows {
                VStack(alignment: .leading, spacing: 8) {
                    progressStatRow(title: "Photos", value: totalCount)
                    progressStatRow(title: "Sorted", value: sortedCount)
                    progressStatRow(title: "Remaining", value: remainingCount)
                }
                .padding(.top, 2)
            }
        }
    }

    private func progressStatRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
