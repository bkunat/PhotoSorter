//
//  PhotoSorter
//

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum PhotoEditorImage {
    enum EditorError: LocalizedError, Equatable {
        case unreadableImage
        case unsupportedFormat
        case multipleImages
        case invalidCrop
        case invalidRotation
        case renderingFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                "This photo could not be opened."
            case .unsupportedFormat:
                "Editing supports JPEG, PNG, HEIC, TIFF, and BMP photos. This photo's format cannot be safely saved."
            case .multipleImages:
                "Photos containing animation or multiple images cannot be edited."
            case .invalidCrop:
                "Select a crop area inside the photo."
            case .invalidRotation:
                "Choose a rotation between −45° and 45°."
            case .renderingFailed:
                "The edited photo could not be rendered."
            case .encodingFailed:
                "The edited photo could not be saved in its original format."
            }
        }
    }

    static func validateSource(at url: URL) throws {
        _ = try source(at: url)
    }

    static func load(from url: URL) throws -> CGImage {
        let source = try source(at: url)
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw EditorError.unreadableImage
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        let orientation = (properties?[kCGImagePropertyOrientation as String] as? NSNumber)?.int32Value ?? 1
        guard orientation != 1 else { return image }
        return try render(CIImage(cgImage: image).oriented(forExifOrientation: orientation), matching: image)
    }

    static func rotateClockwise(_ image: CGImage) throws -> CGImage {
        try render(CIImage(cgImage: image).oriented(.right), matching: image)
    }

    static func straightenScale(size: CGSize, degrees: Double) -> CGFloat {
        let radians = CGFloat(degrees * .pi / 180)
        let sine = abs(sin(radians))
        return max(cos(radians) + size.height / size.width * sine,
                   cos(radians) + size.width / size.height * sine)
    }

    static func straighten(_ image: CGImage, degrees: Double) throws -> CGImage {
        guard degrees.isFinite, (-45...45).contains(degrees) else {
            throw EditorError.invalidRotation
        }
        guard degrees != 0 else { return image }
        let size = CGSize(width: image.width, height: image.height)
        let scale = straightenScale(size: size, degrees: degrees)
        let outputSize = CGSize(width: floor(size.width / scale), height: floor(size.height / scale))
        guard outputSize.width >= 1, outputSize.height >= 1 else { throw EditorError.renderingFailed }
        let transform = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(rotationAngle: -CGFloat(degrees * .pi / 180)))
        let centeredTransform = transform.concatenating(CGAffineTransform(
            translationX: outputSize.width / 2, y: outputSize.height / 2
        ))
        // Extend edge pixels only for interpolation at the inscribed crop boundary.
        let rotated = CIImage(cgImage: image).clampedToExtent().transformed(by: centeredTransform)
            .cropped(to: CGRect(origin: .zero, size: outputSize))
        return try render(rotated, matching: image)
    }

    // The selection uses the same top-left origin as the editor's displayed photo.
    static func crop(_ image: CGImage, normalizedRect rect: CGRect) throws -> CGImage {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.minX >= 0, rect.minY >= 0, rect.maxX <= 1, rect.maxY <= 1,
              rect.width > 0, rect.height > 0 else {
            throw EditorError.invalidCrop
        }
        let pixels = CGRect(
            x: rect.minX * CGFloat(image.width),
            y: rect.minY * CGFloat(image.height),
            width: rect.width * CGFloat(image.width),
            height: rect.height * CGFloat(image.height)
        ).integral
        guard let result = image.cropping(to: pixels) else { throw EditorError.invalidCrop }
        return result
    }

    static func encode(_ image: CGImage, preservingSourceAt url: URL) throws -> Data {
        let source = try source(at: url)
        guard let type = CGImageSourceGetType(source) else { throw EditorError.unreadableImage }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            throw EditorError.encodingFailed
        }
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        properties[kCGImagePropertyOrientation as String] = 1
        properties[kCGImagePropertyPixelWidth as String] = image.width
        properties[kCGImagePropertyPixelHeight as String] = image.height
        properties.removeValue(forKey: "ThumbnailImages")
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation as String] = 1
        // Embedded previews and camera crop coordinates no longer describe the edited pixels.
        for key in ["JPEGInterchangeFormat", "JPEGInterchangeFormatLength", "ImageWidth", "ImageLength"] {
            tiff.removeValue(forKey: key)
        }
        properties[kCGImagePropertyTIFFDictionary as String] = tiff
        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exif[kCGImagePropertyExifPixelXDimension as String] = image.width
        exif[kCGImagePropertyExifPixelYDimension as String] = image.height
        exif.removeValue(forKey: kCGImagePropertyExifSubjectArea as String)
        exif.removeValue(forKey: kCGImagePropertyExifMakerNote as String)
        properties[kCGImagePropertyExifDictionary as String] = exif
        properties[kCGImageDestinationLossyCompressionQuality as String] = 0.95
        properties[kCGImageDestinationEmbedThumbnail as String] = false
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw EditorError.encodingFailed }
        return data as Data
    }

    private static func source(at url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) else { throw EditorError.unreadableImage }
        guard CGImageSourceGetCount(source) == 1 else { throw EditorError.multipleImages }
        let supportedTypes = [UTType.jpeg, .png, .heic, .heif, .tiff, .bmp].map(\.identifier)
        let writableTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard supportedTypes.contains(type as String), writableTypes.contains(type as String) else {
            throw EditorError.unsupportedFormat
        }
        return source
    }

    private static func render(_ image: CIImage, matching original: CGImage) throws -> CGImage {
        let colorSpace = original.colorSpace?.model == .rgb
            ? original.colorSpace! : CGColorSpace(name: CGColorSpace.sRGB)!
        guard let result = CIContext().createCGImage(
            image, from: image.extent,
            format: original.bitsPerComponent > 8 ? .RGBA16 : .RGBA8,
            colorSpace: colorSpace
        ) else { throw EditorError.renderingFailed }
        return result
    }
}
