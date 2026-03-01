import Foundation
import CoreGraphics

@MainActor
final class GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func generateComments(
        from image: CGImage,
        model: GeminiModel,
        apiKey: String,
        count: Int
    ) async throws -> CommentBatch {
        let base64Image = try ImageEncoder.encodeToBase64JPEG(image)

        let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let prompt = """
            このスクリーンショットに映っているものについて、短いコメントを\(count)個書け。
            画面の内容を具体的に見て反応しろ。何が映っているか、色、テキスト、レイアウトなど具体的に触れろ。
            1行1コメント。10文字前後。句読点禁止。タメ口。
            最終行にmood(excitement/funny/surprise/cute/boring/beautiful/general)を1単語だけ書け。

            例(ブラウザが映っている場合):
            YouTube開いてるじゃん
            ダークモードだ
            タブ開きすぎ
            検索バーでかいな
            いい感じの画面
            general
            """

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]],
                        ["text": prompt],
                    ],
                ],
            ],
            "generationConfig": [
                "temperature": 0.9,
                "maxOutputTokens": 200,
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        guard let text = parts?.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return parseBatchResponse(text)
    }

    private func parseBatchResponse(_ text: String) -> CommentBatch {
        var lines = text
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

    private func cleanCommentLine(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)

        if let regex = try? NSRegularExpression(pattern: "^\\d+[.):\\s]+", options: []) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        if result.hasPrefix("- ") {
            result = String(result.dropFirst(2))
        }

        result = result.replacingOccurrences(of: "\u{3002}", with: "")
        result = result.replacingOccurrences(of: "\u{3001}", with: "")
        result = result.replacingOccurrences(of: "\u{FF01}", with: "")

        if result.hasPrefix("*") || result.hasPrefix("#") {
            return ""
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private func isRepetitive(_ text: String) -> Bool {
        guard text.count >= 4 else { return false }
        let chars = Array(text)
        let firstChar = chars[0]
        let sameCount = chars.filter { $0 == firstChar }.count
        return Double(sameCount) / Double(chars.count) > 0.8
    }
}

enum GeminiError: Error, LocalizedError {
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let detail): return "Gemini request failed: \(detail)"
        case .invalidResponse: return "Invalid response from Gemini"
        }
    }
}
