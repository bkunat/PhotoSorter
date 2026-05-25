//
//  PhotoSorter
//

import Foundation

struct SessionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(error: SessionError) {
        title = error.alertTitle
        message = [error.errorDescription, error.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }
}
