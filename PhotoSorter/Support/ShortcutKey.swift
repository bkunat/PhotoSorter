//
//  PhotoSorter
//

import Foundation

nonisolated struct ShortcutKey: Hashable, Equatable, Codable, Sendable {
    let rawValue: String

    init?(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard
            trimmed.count == 1,
            let scalar = trimmed.unicodeScalars.first,
            CharacterSet.alphanumerics.contains(scalar)
        else {
            return nil
        }

        rawValue = trimmed
    }

    var displayValue: String {
        rawValue.uppercased()
    }
}
