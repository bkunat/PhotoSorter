//
//  PhotoSorter
//

import Foundation

struct SessionStats: Equatable {
    let totalCount: Int
    let sortedCount: Int
    let remainingCount: Int
    let progress: Double
    let progressPercent: Int
    let isComplete: Bool
    let categoryCounts: [(category: Category, count: Int)]
    let countByCategoryID: [Category.ID: Int]
    let usedCategoryCount: Int
    let categoriesByID: [Category.ID: Category]

    init(photos: [PhotoItem], categories: [Category]) {
        var counts: [Category.ID: Int] = [:]
        var remaining = 0

        for photo in photos {
            if let categoryID = photo.status.assignedCategoryID {
                counts[categoryID, default: 0] += 1
            } else {
                remaining += 1
            }
        }

        totalCount = photos.count
        remainingCount = remaining
        sortedCount = totalCount - remaining
        progress = totalCount == 0 ? 0 : Double(sortedCount) / Double(totalCount)
        progressPercent = Int((progress * 100).rounded())
        isComplete = totalCount > 0 && remaining == 0
        categoryCounts = categories.map { ($0, counts[$0.id, default: 0]) }
        countByCategoryID = counts
        usedCategoryCount = categoryCounts.filter { $0.count > 0 }.count
        categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    static func == (lhs: SessionStats, rhs: SessionStats) -> Bool {
        lhs.totalCount == rhs.totalCount &&
            lhs.sortedCount == rhs.sortedCount &&
            lhs.remainingCount == rhs.remainingCount &&
            lhs.progress == rhs.progress &&
            lhs.progressPercent == rhs.progressPercent &&
            lhs.isComplete == rhs.isComplete &&
            lhs.countByCategoryID == rhs.countByCategoryID &&
            lhs.usedCategoryCount == rhs.usedCategoryCount &&
            lhs.categoriesByID == rhs.categoriesByID &&
            lhs.categoryCounts.count == rhs.categoryCounts.count &&
            zip(lhs.categoryCounts, rhs.categoryCounts).allSatisfy { lhsEntry, rhsEntry in
                lhsEntry.category == rhsEntry.category && lhsEntry.count == rhsEntry.count
            }
    }
}
