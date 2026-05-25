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
                description: Text("This folder contains no supported top-level `.jpg`, `.jpeg`, `.png`, or `.heic` files.")
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
