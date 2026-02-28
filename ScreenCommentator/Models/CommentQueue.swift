import Foundation

@MainActor
class CommentQueue: ObservableObject {
    @Published private(set) var activeComments: [Comment] = []
    private var pendingComments: [Comment] = []
    private let maxActiveComments = 5
    private var releaseTimer: Timer?

    func enqueue(_ comment: Comment) {
        pendingComments.append(comment)
    }

    func startReleasing(interval: TimeInterval = 1.0) {
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.releaseNext()
            }
        }
    }

    func stopReleasing() {
        releaseTimer?.invalidate()
        releaseTimer = nil
    }

    private func releaseNext() {
        // Remove expired comments (older than 5 seconds)
        let now = Date()
        activeComments.removeAll { now.timeIntervalSince($0.timestamp) > 5.0 }

        // Release next pending comment if space available
        if activeComments.count < maxActiveComments, !pendingComments.isEmpty {
            let comment = pendingComments.removeFirst()
            activeComments.append(comment)
        }
    }
}
