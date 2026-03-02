import Foundation

enum CommentParser {
    // MARK: - Cached Regex Patterns

    private static let codeBlockRegex = try! NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)```")
    private static let thinkingTagRegex = try! NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>")
    private static let specialTagRegex = try! NSRegularExpression(pattern: "<\\|[^|]*\\|>[^<]*")
    private static let numberedPrefixRegex = try! NSRegularExpression(pattern: "^\\d+[.):\\s]+")
    private static let emojiRegex = try! NSRegularExpression(
        pattern: "[\\x{1F300}-\\x{1F9FF}\\x{2600}-\\x{27BF}\\x{FE00}-\\x{FE0F}\\x{200D}]"
    )

    // MARK: - Structured JSON response (Smart)

    static func parseStructuredResponse(_ text: String) -> CommentBatch {
        var cleaned = cleanThinkingTags(text)

        // Strip markdown code blocks
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        if let match = codeBlockRegex.firstMatch(in: cleaned, range: range),
           let captureRange = Range(match.range(at: 1), in: cleaned) {
            cleaned = String(cleaned[captureRange])
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct JSON parse
        if let data = cleaned.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return extractFromJSON(json)
        }

        // Try to extract JSON by finding outermost { ... }
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}"),
           firstBrace < lastBrace {
            let jsonSubstring = String(cleaned[firstBrace...lastBrace])
            if let data = jsonSubstring.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return extractFromJSON(json)
            }
        }

        print("[ScreenCommentator] Smart JSON parse failed, raw response: \(cleaned.prefix(500))")
        return parseBatchResponse(cleaned)
    }

    private static func extractFromJSON(_ json: [String: Any]) -> CommentBatch {
        let comments: [String]
        if let arr = json["comments"] as? [String] {
            comments = arr.compactMap { line -> String? in
                let trimmed = cleanCommentLine(line)
                guard !trimmed.isEmpty else { return nil }
                return String(trimmed.prefix(40))
            }
        } else {
            comments = []
        }

        let mood: String
        if let m = json["mood"] as? String, validMoods.contains(m.lowercased()) {
            mood = m.lowercased()
        } else {
            mood = "general"
        }

        let excitement: Int
        if let e = json["excitement"] as? Int {
            excitement = max(1, min(10, e))
        } else if let e = json["excitement"] as? Double {
            excitement = max(1, min(10, Int(e)))
        } else {
            excitement = 5
        }

        return CommentBatch(comments: comments, mood: mood, excitement: excitement)
    }

    // MARK: - Line-based response (OCR / Basic)

    static func parseBatchResponse(_ text: String) -> CommentBatch {
        let cleaned = cleanThinkingTags(text)

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
            guard trimmed.count >= 2 else { return nil }
            if isRepetitive(trimmed) { return nil }
            if looksLikeJSONFragment(trimmed) { return nil }
            return trimmed
        }

        return CommentBatch(comments: comments, mood: mood)
    }

    // MARK: - Helpers

    private static func cleanThinkingTags(_ text: String) -> String {
        var cleaned = text
        let range1 = NSRange(cleaned.startIndex..., in: cleaned)
        cleaned = thinkingTagRegex.stringByReplacingMatches(in: cleaned, range: range1, withTemplate: "")
        let range2 = NSRange(cleaned.startIndex..., in: cleaned)
        cleaned = specialTagRegex.stringByReplacingMatches(in: cleaned, range: range2, withTemplate: "")
        return cleaned
    }

    static func cleanCommentLine(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)

        let range = NSRange(result.startIndex..., in: result)
        result = numberedPrefixRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")

        if result.hasPrefix("- ") {
            result = String(result.dropFirst(2))
        }

        result = result.replacingOccurrences(of: "\u{3002}", with: "")
        result = result.replacingOccurrences(of: "\u{3001}", with: "")
        result = result.replacingOccurrences(of: "\u{FF01}", with: "")

        if result.hasPrefix("*") || result.hasPrefix("#") {
            return ""
        }

        let emojiRange = NSRange(result.startIndex..., in: result)
        result = emojiRegex.stringByReplacingMatches(in: result, range: emojiRange, withTemplate: "")

        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func looksLikeJSONFragment(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t == "{" || t == "}" || t == "[" || t == "]" { return true }
        if t.hasPrefix("\"") && t.contains(":") { return true }
        if t.hasPrefix("{\"") || t.hasPrefix("[\"") { return true }
        if t.hasSuffix(",") && (t.contains("\"") && t.contains(":")) { return true }
        return false
    }

    private static func isRepetitive(_ text: String) -> Bool {
        guard text.count >= 4 else { return false }
        let chars = Array(text)
        let firstChar = chars[0]
        let sameCount = chars.filter { $0 == firstChar }.count
        return Double(sameCount) / Double(chars.count) > 0.8
    }
}
