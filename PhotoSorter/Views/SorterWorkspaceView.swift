//
//  PhotoSorter
//

import SwiftUI

struct SorterWorkspaceView: View {
    private static let carouselSurfaceTopCornerRadius: CGFloat = 32
    private static let carouselSurfaceBottomCornerRadius: CGFloat = 10

    let photos: [PhotoItem]
    let categories: [Category]
    let stats: SessionStats
    let currentPhotoIndex: Int?
    let currentPhoto: PhotoItem?
    let currentPhotoCategory: Category?
    let activeFeedback: SessionFeedback?
    let canUndo: Bool
    let onSelectPhoto: (Int) -> Void
    let onChooseAnotherFolder: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                PhotoHeaderView(
                    stats: stats,
                    currentPhotoIndex: currentPhotoIndex,
                    currentPhotoCategory: currentPhotoCategory
                )
                .padding(.horizontal, 28)
                .padding(.top, 20)

                if stats.isComplete {
                    CompletionSummaryView(
                        sortedCount: stats.sortedCount,
                        totalCount: stats.totalCount,
                        categoryCount: stats.usedCategoryCount,
                        progressPercent: stats.progressPercent,
                        onChooseAnotherFolder: onChooseAnotherFolder
                    )
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                PhotoCarouselView(
                    photos: photos,
                    categoriesByID: stats.categoriesByID,
                    currentPhotoIndex: currentPhotoIndex,
                    onSelectPhoto: onSelectPhoto
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .background(
                    carouselSurfaceShape
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            carouselSurfaceShape
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)

                if let footerMessage {
                    footer(message: footerMessage)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let activeFeedback {
                SessionFeedbackToast(
                    feedback: activeFeedback,
                    tint: feedbackTint(for: activeFeedback)
                )
                .padding(.top, 76)
                .padding(.trailing, 28)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: activeFeedback?.id)
        .animation(.easeInOut(duration: 0.22), value: stats.isComplete)
    }

    private var carouselSurfaceShape: some InsettableShape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: Self.carouselSurfaceTopCornerRadius,
                bottomLeading: Self.carouselSurfaceBottomCornerRadius,
                bottomTrailing: Self.carouselSurfaceBottomCornerRadius,
                topTrailing: Self.carouselSurfaceTopCornerRadius
            ),
            style: .continuous
        )
    }

    private var footerMessage: String? {
        if stats.isComplete {
            return "Sorting complete. Use arrow keys to review."
        }

        if categories.isEmpty {
            return "Create a category to start sorting."
        }

        if let currentPhoto, !currentPhoto.status.isUncategorized {
            return "Current photo is already categorized. Press Delete to return it to the root."
        }

        if canUndo {
            return "Press Command-Z to undo the last move."
        }

        return nil
    }

    private func footer(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func feedbackTint(for feedback: SessionFeedback) -> Color {
        guard
            let categoryID = feedback.categoryID,
            let category = stats.categoriesByID[categoryID]
        else {
            return stats.isComplete ? .green : .accentColor
        }

        return Color(nsColor: CategoryColorPalette.color(for: category))
    }
}
