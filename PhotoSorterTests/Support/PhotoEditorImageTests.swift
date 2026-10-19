//
//  PhotoSorter
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PhotoSorter

final class PhotoEditorImageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        directory = nil
    }

    func testClockwiseRotationPlacesPixelsAndFourTurnsRestoreImage() throws {
        let original = try makeImage()
        let rotated = try PhotoEditorImage.rotateClockwise(original)

        XCTAssertEqual(rotated.width, 3)
        XCTAssertEqual(rotated.height, 2)
        XCTAssertEqual(try rgbPixels(rotated), [
            0, 0, 0, 0, 0, 255, 255, 0, 0,
            255, 255, 0, 255, 255, 255, 0, 255, 0
        ])
        var restored = rotated
        for _ in 0..<3 { restored = try PhotoEditorImage.rotateClockwise(restored) }
        XCTAssertEqual(try rgbPixels(restored), try rgbPixels(original))
    }

    func testStraighteningZeroReturnsOriginalImage() throws {
        let original = try makeImage()

        XCTAssertTrue(try PhotoEditorImage.straighten(original, degrees: 0) === original)
        XCTAssertEqual(PhotoEditorImage.straightenScale(size: CGSize(width: 240, height: 180), degrees: 0), 1)
    }

    func testStraighteningCropsToInscribedRectangleWithoutEmptyCorners() throws {
        let landscape = try makeStraighteningImage()
        let portrait = try PhotoEditorImage.rotateClockwise(landscape)
        for image in [landscape, portrait] {
            for degrees in [-45.0, -15, -2.5, 2.5, 15, 45] {
                let rotated = try PhotoEditorImage.straighten(image, degrees: degrees)
                let scale = PhotoEditorImage.straightenScale(
                    size: CGSize(width: image.width, height: image.height), degrees: degrees
                )
                XCTAssertEqual(rotated.width, Int(floor(CGFloat(image.width) / scale)))
                XCTAssertEqual(rotated.height, Int(floor(CGFloat(image.height) / scale)))
                let pixels = try rgbaPixels(rotated)
                for index in [0, rotated.width - 1, (rotated.height - 1) * rotated.width,
                              rotated.height * rotated.width - 1] {
                    XCTAssertEqual(pixels[index * 4 + 3], 255, "Empty corner at \(degrees)°")
                    XCTAssertGreaterThan(Int(pixels[index * 4]) + Int(pixels[index * 4 + 2]), 200)
                }
            }
        }
    }

    func testPositiveStraighteningRotatesClockwise() throws {
        let original = try makeStraighteningImage()
        for degrees in [-15.0, 15] {
            let rotated = try PhotoEditorImage.straighten(original, degrees: degrees)
            let pixels = try rgbaPixels(rotated)
            let index = (rotated.height / 2 * rotated.width + rotated.width * 3 / 4) * 4
            XCTAssertEqual(Array(pixels[index..<(index + 3)]), degrees > 0 ? [255, 0, 0] : [0, 0, 255])
        }
    }

    func testStraighteningRejectsInvalidAngles() throws {
        let image = try makeImage()
        for degrees in [-45.1, 45.1, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try PhotoEditorImage.straighten(image, degrees: degrees)) { error in
                XCTAssertEqual(error as? PhotoEditorImage.EditorError, .invalidRotation)
            }
        }
    }

    func testCropUsesTopLeftCoordinates() throws {
        let original = try makeImage()

        let topLeft = try PhotoEditorImage.crop(original, normalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0 / 3))
        let bottomRight = try PhotoEditorImage.crop(original, normalizedRect: CGRect(x: 0.5, y: 2.0 / 3, width: 0.5, height: 1.0 / 3))

        XCTAssertEqual(topLeft.width, 1)
        XCTAssertEqual(topLeft.height, 1)
        XCTAssertEqual(try rgbPixels(topLeft), [255, 0, 0])
        XCTAssertEqual(try rgbPixels(bottomRight), [255, 255, 0])
    }

    func testCropRejectsEmptyOutOfBoundsAndNonfiniteSelections() throws {
        let image = try makeImage()
        for rect in [
            CGRect.zero,
            CGRect(x: -0.1, y: 0, width: 0.5, height: 0.5),
            CGRect(x: 0.9, y: 0, width: 0.2, height: 0.5),
            CGRect(x: 0, y: 0, width: -0.5, height: 0.5),
            CGRect(x: CGFloat.infinity, y: 0, width: 0.5, height: 0.5),
            CGRect(x: 0, y: 0, width: CGFloat.nan, height: 0.5)
        ] {
            XCTAssertThrowsError(try PhotoEditorImage.crop(image, normalizedRect: rect)) { error in
                XCTAssertEqual(error as? PhotoEditorImage.EditorError, .invalidCrop)
            }
        }
    }

    func testLoadNormalizesExifOrientation() throws {
        let original = try makeImage()
        let url = try writeImage(original, type: .tiff, properties: [kCGImagePropertyOrientation as String: 6])

        let loaded = try PhotoEditorImage.load(from: url)

        XCTAssertEqual(loaded.width, 3)
        XCTAssertEqual(loaded.height, 2)
        XCTAssertEqual(try rgbPixels(loaded), try rgbPixels(PhotoEditorImage.rotateClockwise(original)))
    }

    func testEncodingPreservesFormatAndMetadataAndResetsOrientationAndDimensions() throws {
        let original = try makeImage()
        let sourceURL = try writeImage(original, type: .jpeg, properties: [
            kCGImagePropertyOrientation as String: 6,
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:10:19 12:00:00"
            ]
        ])
        let loaded = try PhotoEditorImage.load(from: sourceURL)
        let cropped = try PhotoEditorImage.crop(loaded, normalizedRect: CGRect(x: 0, y: 0, width: 1.0 / 3, height: 1))

        let data = try PhotoEditorImage.encode(cropped, preservingSourceAt: sourceURL)

        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        XCTAssertEqual(properties[kCGImagePropertyOrientation as String] as? Int, 1)
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth as String] as? Int, 1)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight as String] as? Int, 2)
        let exif = try XCTUnwrap(properties[kCGImagePropertyExifDictionary as String] as? [String: Any])
        XCTAssertEqual(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String, "2026:10:19 12:00:00")
        let outputURL = directory.appendingPathComponent("edited.jpg")
        try data.write(to: outputURL)
        let reloaded = try PhotoEditorImage.load(from: outputURL)
        XCTAssertEqual(reloaded.width, 1)
        XCTAssertEqual(reloaded.height, 2)
    }

    func testPNGEncodingKeepsPixelsAndOriginalFileUntouched() throws {
        let image = try makeImage()
        let url = try writeImage(image, type: .png)
        let originalData = try Data(contentsOf: url)
        let rotated = try PhotoEditorImage.rotateClockwise(image)

        let encoded = try PhotoEditorImage.encode(rotated, preservingSourceAt: url)

        XCTAssertEqual(try Data(contentsOf: url), originalData)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.png.identifier)
        XCTAssertEqual(try rgbPixels(XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))), try rgbPixels(rotated))
    }

    func testRejectsAnimatedAndMultipageSources() throws {
        let image = try makeImage()
        for type in [UTType.gif, .tiff] {
            let url = try writeImage(image, type: type, count: 2)
            let fixture = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            XCTAssertEqual(CGImageSourceGetCount(fixture), 2)
            XCTAssertThrowsError(try PhotoEditorImage.load(from: url)) { error in
                XCTAssertEqual(error as? PhotoEditorImage.EditorError, .multipleImages)
            }
            XCTAssertThrowsError(try PhotoEditorImage.encode(image, preservingSourceAt: url))
        }
    }

    func testRejectsUnsupportedAndUnreadableSources() throws {
        let gifURL = try writeImage(makeImage(), type: .gif)
        XCTAssertThrowsError(try PhotoEditorImage.validateSource(at: gifURL)) { error in
            XCTAssertEqual(error as? PhotoEditorImage.EditorError, .unsupportedFormat)
        }
        let invalidURL = directory.appendingPathComponent("broken.jpg")
        try Data("not an image".utf8).write(to: invalidURL)
        XCTAssertThrowsError(try PhotoEditorImage.load(from: invalidURL))
    }

    private func makeImage(alternate: Bool = false) throws -> CGImage {
        var pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 255, 255,
            0, 0, 0, 255, 255, 255, 0, 255
        ]
        if alternate { pixels.swapAt(0, 1) }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(
            width: 2, height: 3, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }

    private func rgbPixels(_ image: CGImage) throws -> [UInt8] {
        let pixels = try rgbaPixels(image)
        return stride(from: 0, to: pixels.count, by: 4).flatMap { Array(pixels[$0..<($0 + 3)]) }
    }

    private func rgbaPixels(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private func makeStraighteningImage() throws -> CGImage {
        let width = 240
        let height = 180
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                pixels[index + (y < height / 2 ? 0 : 2)] = 255
                pixels[index + 3] = 255
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }

    private func writeImage(
        _ image: CGImage, type: UTType, count: Int = 1, properties: [String: Any] = [:]
    ) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(type.preferredFilenameExtension ?? "image")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, count, nil))
        for index in 0..<count {
            let frame = index == 0 ? image : try makeImage(alternate: true)
            CGImageDestinationAddImage(destination, frame, properties as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }
}
