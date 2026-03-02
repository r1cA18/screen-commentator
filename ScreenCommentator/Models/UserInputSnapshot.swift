import Foundation
import CoreGraphics
import AppKit

struct UserInputSnapshot: Sendable {
    let recentClicks: Int
    let recentScrolls: Int
    let isTyping: Bool
    let lastClickLocation: CGPoint?

    static let empty = UserInputSnapshot(recentClicks: 0, recentScrolls: 0, isTyping: false, lastClickLocation: nil)

    var promptDescription: String {
        var parts: [String] = []

        if recentClicks > 3 {
            parts.append("頻繁にクリックしている(\(recentClicks)回)")
        } else if recentClicks > 0 {
            parts.append("クリックした(\(recentClicks)回)")
        }

        if recentScrolls > 3 {
            parts.append("たくさんスクロールしている")
        } else if recentScrolls > 0 {
            parts.append("スクロールした")
        }

        if isTyping {
            parts.append("テキストを入力中")
        }

        if let loc = lastClickLocation {
            let screenWidth = NSScreen.main?.frame.width ?? 1920
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            let xZone = loc.x < screenWidth / 3 ? "左" : loc.x > screenWidth * 2 / 3 ? "右" : "中央"
            let yZone = loc.y < screenHeight / 3 ? "上" : loc.y > screenHeight * 2 / 3 ? "下" : "中央"
            parts.append("最後のクリック位置: \(yZone)\(xZone)")
        }

        if parts.isEmpty {
            return "操作なし"
        }
        return parts.joined(separator: ", ")
    }
}
