import Foundation

enum CommentParser {
    static func parseBatchResponse(_ text: String) -> CommentBatch {
        var cleaned = text

        // Remove thinking model tags
        if let regex = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: ""
            )
        }

        // Remove special tokens
        if let regex = try? NSRegularExpression(pattern: "<\\|[^|]*\\|>[^<]*", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: ""
            )
        }

        var lines = cleaned
            .components(separatedBy: .newlines)
            .map { cleanCommentLine($0) }
            .filter { !$0.isEmpty }

        var mood = "general"
        if let lastLine = lines.last {
            let normalized = lastLine.lowercased()
                .replacingOccurrences(of: "mood:", with: "")
                .replacingOccurrences(of: "mood", with: "")
                .trimmingCharacters(in: .whitespaces)
            if validMoods.contains(normalized) {
                mood = normalized
                lines.removeLast()
            }
        }

        let comments = lines.compactMap { line -> String? in
            let trimmed = String(line.prefix(40))
            guard trimmed.count >= 1 else { return nil }
            if isRepetitive(trimmed) { return nil }
            return trimmed
        }

        return CommentBatch(comments: comments, mood: mood)
    }

    private static func cleanCommentLine(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)

        // Remove numbered prefixes (1. 2) 3: etc.)
        if let regex = try? NSRegularExpression(pattern: "^\\d+[.):\\s]+", options: []) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        if result.hasPrefix("- ") {
            result = String(result.dropFirst(2))
        }

        // Remove Japanese punctuation
        result = result.replacingOccurrences(of: "\u{3002}", with: "")
        result = result.replacingOccurrences(of: "\u{3001}", with: "")
        result = result.replacingOccurrences(of: "\u{FF01}", with: "")

        // Remove markdown headers/emphasis
        if result.hasPrefix("*") || result.hasPrefix("#") {
            return ""
        }

        // Remove emoji
        if let regex = try? NSRegularExpression(
            pattern: "[\\u{1F300}-\\u{1F9FF}\\u{2600}-\\u{27BF}\\u{FE00}-\\u{FE0F}\\u{200D}]",
            options: []
        ) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func isRepetitive(_ text: String) -> Bool {
        guard text.count >= 4 else { return false }
        let chars = Array(text)
        let firstChar = chars[0]
        let sameCount = chars.filter { $0 == firstChar }.count
        return Double(sameCount) / Double(chars.count) > 0.8
    }
}
