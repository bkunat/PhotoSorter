//
//  PhotoSorter
//

import SwiftUI

struct CategoryDistributionView: View {
    let categoryCounts: [(category: Category, count: Int)]
    let totalPhotoCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(categoryCounts, id: \.category.id) { entry in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(categoryTint(for: entry.category))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    Text(entry.category.name)
                        .font(.footnote)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(entry.count)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()

                    if totalPhotoCount > 0 {
                        Text("\(categoryPercent(for: entry.count))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(entry.category.name), \(entry.count) sorted photos")
            }
        }
    }

    private func categoryPercent(for count: Int) -> Int {
        guard totalPhotoCount > 0 else { return 0 }
        return Int((Double(count) / Double(totalPhotoCount) * 100).rounded())
    }

    private func categoryTint(for category: Category) -> Color {
        Color(nsColor: CategoryColorPalette.color(for: category))
    }
}
