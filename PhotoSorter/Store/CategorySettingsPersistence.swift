//
//  PhotoSorter
//

import Foundation

nonisolated struct SavedCategory: Codable, Sendable {
    let id: UUID
    let name: String
    let shortcut: String
}

nonisolated struct CategorySettings: Codable, Sendable {
    let categories: [SavedCategory]
    let includesOtherFolders: Bool
}

struct CategorySettingsPersistence {
    private static let defaultsKey = "categorySettingsByFolder"
    let userDefaults: UserDefaults

    func load(for directoryURL: URL) -> CategorySettings? {
        guard let data = userDefaults.dictionary(forKey: Self.defaultsKey)?[directoryURL.standardizedFileURL.path] as? Data else {
            return nil
        }
        do {
            return try JSONDecoder().decode(CategorySettings.self, from: data)
        } catch {
            AppLogger.error("Could not read category settings: \(error.localizedDescription)", category: .session)
            return nil
        }
    }

    func save(categories: [Category], includesOtherFolders: Bool, for directoryURL: URL) {
        let settings = CategorySettings(
            categories: categories.map { SavedCategory(id: $0.id, name: $0.name, shortcut: $0.shortcut.rawValue) },
            includesOtherFolders: includesOtherFolders
        )
        do {
            var entries = userDefaults.dictionary(forKey: Self.defaultsKey) ?? [:]
            entries[directoryURL.standardizedFileURL.path] = try JSONEncoder().encode(settings)
            userDefaults.set(entries, forKey: Self.defaultsKey)
        } catch {
            AppLogger.error("Could not save category settings: \(error.localizedDescription)", category: .session)
        }
    }
}
