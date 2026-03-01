@preconcurrency import ScreenCaptureKit
import Foundation
import AppKit

@MainActor
final class ScreenCaptureService {
    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    func startCapturing(interval: TimeInterval) async throws -> AsyncStream<CGImage> {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(seconds: interval, preferredTimescale: 600)
        config.showsCursor = false

        let scStream = SCStream(filter: filter, configuration: config, delegate: nil)

        let (asyncStream, continuation) = AsyncStream.makeStream(of: CGImage.self)

        let output = StreamOutput { image in
            continuation.yield(image)
        }

        try scStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global())
        try await scStream.startCapture()

        self.stream = scStream
        self.streamOutput = output

        return asyncStream
    }

    func stopCapturing() {
        guard let stream else { return }
        let capturedStream = stream
        self.stream = nil
        self.streamOutput = nil
        Task {
            try? await capturedStream.stopCapture()
        }
    }
}

// MARK: - StreamOutput

private final class StreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let handler: (CGImage) -> Void
    private let ciContext = CIContext()

    init(handler: @escaping (CGImage) -> Void) {
        self.handler = handler
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        handler(cgImage)
    }
}

// MARK: - Error

enum CaptureError: Error, LocalizedError {
    case noDisplayFound

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for screen capture"
        }
    }
}
