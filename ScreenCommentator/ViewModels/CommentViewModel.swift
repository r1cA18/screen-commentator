import Foundation
import SwiftUI

@MainActor
class CommentViewModel: ObservableObject {
    @Published var commentQueue = CommentQueue()
    @Published var isRunning = false

    private let captureService = ScreenCaptureService()
    private let ollamaService = OllamaService()
    private var captureTimer: Timer?
    private let captureInterval: TimeInterval = 5.0

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Start comment queue releasing
        commentQueue.startReleasing(interval: 1.0)

        // Start screen capture
        do {
            try await captureService.startCapturing(interval: captureInterval) { [weak self] image in
                Task { @MainActor in
                    await self?.processCapture(image)
                }
            }
        } catch {
            print("Failed to start capture: \(error)")
            isRunning = false
        }
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false

        captureTimer?.invalidate()
        captureTimer = nil
        commentQueue.stopReleasing()
        await captureService.stopCapturing()
    }

    private func processCapture(_ image: CGImage) async {
        do {
            let comment = try await ollamaService.generateComment(from: image)
            commentQueue.enqueue(Comment(text: comment))
        } catch {
            print("Failed to generate comment: \(error)")
        }
    }
}
