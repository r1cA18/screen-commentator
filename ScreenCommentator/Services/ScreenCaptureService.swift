import Foundation
import ScreenCaptureKit
import AppKit

@MainActor
class ScreenCaptureService {
    private var stream: SCStream?
    private var filter: SCContentFilter?

    func startCapturing(interval: TimeInterval, onCapture: @escaping (CGImage) -> Void) async throws {
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Create filter for the entire display
        let filter = SCContentFilter(display: display, excludingWindows: [])
        self.filter = filter

        // Configure stream
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(seconds: interval, preferredTimescale: 600)
        config.showsCursor = false

        // Create stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.stream = stream

        // Add output handler
        try stream.addStreamOutput(StreamOutput(onCapture: onCapture), type: .screen, sampleHandlerQueue: .main)

        // Start capture
        try await stream.startCapture()
    }

    func stopCapturing() async {
        guard let stream = stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
    }
}

// MARK: - StreamOutput
private class StreamOutput: NSObject, SCStreamOutput {
    private let onCapture: (CGImage) -> Void

    init(onCapture: @escaping (CGImage) -> Void) {
        self.onCapture = onCapture
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        onCapture(cgImage)
    }
}

// MARK: - Error
enum CaptureError: Error {
    case noDisplayFound
}
