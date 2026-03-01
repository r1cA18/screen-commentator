import AppKit
import CoreGraphics

enum ImageEncoder {
    private static let maxDimension: CGFloat = 1024

    static func encodeToBase64JPEG(_ cgImage: CGImage, quality: CGFloat = 0.7) throws -> String {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let scale: CGFloat
        if max(width, height) > maxDimension {
            scale = maxDimension / max(width, height)
        } else {
            scale = 1.0
        }

        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        let nsImage: NSImage
        if scale < 1.0 {
            nsImage = NSImage(size: NSSize(width: newWidth, height: newHeight))
            nsImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            NSImage(cgImage: cgImage, size: .zero).draw(
                in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
            nsImage.unlockFocus()
        } else {
            nsImage = NSImage(cgImage: cgImage, size: NSSize(width: newWidth, height: newHeight))
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(
                  using: .jpeg,
                  properties: [.compressionFactor: quality]
              ) else {
            throw ImageEncoderError.conversionFailed
        }

        return jpegData.base64EncodedString()
    }
}

enum ImageEncoderError: Error, LocalizedError {
    case conversionFailed

    var errorDescription: String? {
        "Failed to convert screen capture to JPEG"
    }
}
