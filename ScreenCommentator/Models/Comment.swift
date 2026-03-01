import Foundation

struct Comment: Sendable {
    let id: UUID
    let text: String
    let lane: Int
    let timestamp: Date

    init(text: String, lane: Int) {
        self.id = UUID()
        self.text = text
        self.lane = lane
        self.timestamp = Date()
    }
}

extension Comment: Identifiable {}

struct CommentBatch: Sendable {
    let comments: [String]
    let mood: String
}

let validMoods: Set<String> = [
    "excitement", "funny", "surprise", "cute", "boring", "beautiful", "general",
]
