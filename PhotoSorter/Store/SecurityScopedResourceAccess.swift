//
//  PhotoSorter
//

import Foundation

protocol SecurityScopedResourceAccess: AnyObject {
    nonisolated func startAccessing(_ url: URL) -> Bool
    nonisolated func stopAccessing(_ url: URL)
}

final class DefaultSecurityScopedResourceAccess: SecurityScopedResourceAccess {
    nonisolated init() {}

    nonisolated func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    nonisolated func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
