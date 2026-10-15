//
//  PhotoSorter
//

import SwiftUI

private struct SessionCommandsEnabledKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var sessionCommandsEnabled: Bool? {
        get { self[SessionCommandsEnabledKey.self] }
        set { self[SessionCommandsEnabledKey.self] = newValue }
    }
}
