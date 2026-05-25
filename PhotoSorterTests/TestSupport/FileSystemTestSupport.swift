//
//  PhotoSorter
//

import AppKit
import XCTest

extension XCTestCase {
    func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoSorterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        addTeardownBlock {
            _ = try? FileManager.default.removeItem(at: directoryURL)
        }

        return directoryURL
    }

    @discardableResult
    func createFile(named name: String, in directoryURL: URL, contents: Data = Data()) -> URL {
        let fileURL = directoryURL.appendingPathComponent(name)
        FileManager.default.createFile(atPath: fileURL.path, contents: contents)
        return fileURL
    }

    @discardableResult
    func createDirectory(named name: String, in directoryURL: URL) throws -> URL {
        let nestedDirectoryURL = directoryURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)
        return nestedDirectoryURL
    }

    func itemExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func fileExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    @discardableResult
    func createTinyPNG(named name: String, in directoryURL: URL) -> URL {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()

        let data = image.tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) } ?? Data()

        return createFile(named: name, in: directoryURL, contents: data)
    }
}
