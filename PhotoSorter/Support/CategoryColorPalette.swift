//
//  PhotoSorter
//

import AppKit

enum CategoryColorPalette {
    private static let palette: [NSColor] = [
        NSColor(calibratedRed: 0.84, green: 1.00, blue: 0.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.24, blue: 0.45, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.84, blue: 0.88, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.41, blue: 0.00, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.66, blue: 0.66, alpha: 1),
        NSColor(calibratedRed: 0.56, green: 0.22, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.00, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.55, blue: 1.00, alpha: 1)
    ]

    static func color(for category: Category) -> NSColor {
        automaticColor(fallbackName: category.name)
    }

    static func automaticColor(fallbackName: String) -> NSColor {
        let scalarSum = fallbackName.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult += Int(scalar.value)
        }

        return palette[scalarSum % palette.count]
    }
}
