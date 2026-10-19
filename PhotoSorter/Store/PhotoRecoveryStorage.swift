//
//  PhotoSorter
//

import Foundation

struct PhotoRecoveryStorage {
    let directoryURL: URL
    let fileManager: FileManager

    func validateRegularFile(_ url: URL, inside directory: URL) throws {
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard resolved.starts(with: root), resolved.count > root.count,
              attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.referenceCount] as? NSNumber)?.intValue == 1 else {
            throw SessionError.unsafePhotoFile(url.lastPathComponent)
        }
    }

    func backup(_ url: URL, workingDirectory: URL) throws -> URL {
        try validateRegularFile(url, inside: workingDirectory)
        let root = workingDirectory.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard !directoryURL.resolvingSymlinksInPath().standardizedFileURL.pathComponents.starts(with: root) else {
            throw SessionError.recoveryStorageInWorkingDirectory
        }
        let backupDirectory = directoryURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let backupURL = backupDirectory.appendingPathComponent(url.lastPathComponent)
        // Keep a human-readable source path so retained copies remain useful after quitting.
        try Data(url.path.utf8).write(to: backupDirectory.appendingPathComponent("source-path.txt"), options: .atomic)
        try fileManager.copyItem(at: url, to: backupURL)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
        AppLogger.info("Preserved \(url.lastPathComponent) at \(backupURL.path)", category: .fileSystem)
        return backupURL
    }
}
