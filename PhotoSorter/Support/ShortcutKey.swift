//
//  PhotoSorter
//

import Foundation

struct ShortcutKey: Hashable, Equatable, Codable {
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
