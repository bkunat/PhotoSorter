//
//  PhotoSorter
//

import SwiftUI

struct SessionFeedbackToast: View {
    let feedback: SessionFeedback
    let tint: Color

    var body: some View {
        Label(feedback.message, systemImage: feedback.systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.primary)
            .background(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .accessibilityLabel(feedback.message)
    }
}
