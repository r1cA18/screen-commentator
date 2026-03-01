import Foundation
import AppKit
import CoreGraphics

enum OllamaModel: String, CaseIterable, Identifiable, Sendable {
    case qwen25vl_3b = "qwen2.5vl:3b"
    case gemma3_4b = "gemma3:4b"
    case gemma3_12b = "gemma3:12b"
    case qwen3_vl_8b = "qwen3-vl:8b"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen25vl_3b: return "Qwen2.5-VL 3B (fast)"
        case .gemma3_4b: return "Gemma 3 4B"
        case .gemma3_12b: return "Gemma 3 12B"
        case .qwen3_vl_8b: return "Qwen3-VL 8B (slow)"
        }
    }

    var isThinkingModel: Bool {
        switch self {
        case .qwen3_vl_8b: return true
        default: return false
        }
    }
}

@MainActor
final class OllamaService {
    private let baseURL = "http://127.0.0.1:11434"

    func generateComments(from image: CGImage, model: OllamaModel, count: Int) async throws -> CommentBatch {
        let base64Image = try ImageEncoder.encodeToBase64JPEG(image)

        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

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

        let numPredict = model.isThinkingModel ? 512 : (count * 25 + 30)

        var options: [String: Any] = [
            "temperature": 0.9,
            "top_p": 0.95,
            "num_predict": numPredict,
            "repeat_penalty": 1.5,
        ]
        if !model.isThinkingModel {
            options["num_ctx"] = 2048
        }

        let payload: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                [
                    "role": "user",
                    "content": prompt,
                    "images": [base64Image],
                ],
            ],
            "stream": false,
            "options": options,
            "keep_alive": "10m",
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = json?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else {
            throw OllamaError.invalidResponse
        }

        return parseBatchResponse(content)
    }

    private func parseBatchResponse(_ text: String) -> CommentBatch {
        var cleaned = text

        if let regex = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: ""
            )
        }

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

    private func isRepetitive(_ text: String) -> Bool {
        guard text.count >= 4 else { return false }
        let chars = Array(text)
        let firstChar = chars[0]
        let sameCount = chars.filter { $0 == firstChar }.count
        return Double(sameCount) / Double(chars.count) > 0.8
    }

    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func ensureRunning(maxWait: TimeInterval = 15) async -> Bool {
        if await checkConnection() { return true }

        let launched = launchOllamaApp()
        guard launched else { return false }

        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(1))
            if await checkConnection() { return true }
        }
        return false
    }

    private func launchOllamaApp() -> Bool {
        let candidates = [
            "/Applications/Ollama.app",
            NSString("~/Applications/Ollama.app").expandingTildeInPath,
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                return NSWorkspace.shared.open(url)
            }
        }
        return false
    }
}

enum OllamaError: Error, LocalizedError {
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Ollama request failed - is Ollama running?"
        case .invalidResponse:
            return "Invalid response from Ollama"
        }
    }
}
