import Foundation
import SwiftUI

enum CommentStyle: String, Sendable {
    case scroll
    case top
    case bottom
}

enum CommentColor: String, CaseIterable, Sendable {
    case white, red, pink, orange, yellow, green, cyan, blue, purple

    var swiftUIColor: Color {
        switch self {
        case .white: return .white
        case .red: return .red
        case .pink: return .pink
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .purple: return .purple
        }
    }
}

struct Comment: Sendable {
    let id: UUID
    let text: String
    let lane: Int
    let timestamp: Date
    let style: CommentStyle
    let color: CommentColor
    let speedMultiplier: Double

    init(text: String, lane: Int, style: CommentStyle = .scroll, color: CommentColor = .white, speedMultiplier: Double = 1.0) {
        self.id = UUID()
        self.text = text
        self.lane = lane
        self.timestamp = Date()
        self.style = style
        self.color = color
        self.speedMultiplier = speedMultiplier
    }
}

extension Comment: Identifiable {}

struct CommentBatch: Sendable {
    let comments: [String]
    let mood: String
    let excitement: Int

    init(comments: [String], mood: String, excitement: Int = 5) {
        self.comments = comments
        self.mood = mood
        self.excitement = excitement
    }
}

let validMoods: Set<String> = [
    "excitement", "funny", "surprise", "cute", "boring", "beautiful", "general",
]
