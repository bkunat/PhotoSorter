//
//  PhotoSorter
//

import SwiftUI

struct EmptyFolderView: View {
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "No Supported Photos Found",
                systemImage: "photo.on.rectangle.angled",
                description: Text("No JPG, JPEG, PNG, or HEIC images were found in the selected folders.")
            )

            Button("Choose Another Folder", systemImage: "folder") {
                onChooseFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
