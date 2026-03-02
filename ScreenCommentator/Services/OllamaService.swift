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

    func generateComments(
        from image: CGImage?,
        model: OllamaModel,
        persona: Persona,
        count: Int,
        context: PromptContext,
        pipelineMode: PipelineMode
    ) async throws -> CommentBatch {
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let prompt: String
        let includeImage: Bool
        let useJsonFormat: Bool

        switch pipelineMode {
        case .smart:
            prompt = Persona.buildSmartPrompt(enabledPersonas: context.enabledPersonas, count: count, context: context)
            includeImage = true
            useJsonFormat = true
        case .ocrEnhanced:
            prompt = Persona.buildOCRPrompt(persona: persona, count: count, context: context)
            includeImage = false
            useJsonFormat = false
        case .basic:
            prompt = Persona.buildBasicPrompt(persona: persona, count: count)
            includeImage = true
            useJsonFormat = false
        }

        let numPredict: Int
        if model.isThinkingModel {
            numPredict = 512
        } else if useJsonFormat {
            numPredict = max(300, count * 40 + 60)
        } else {
            numPredict = count * 25 + 30
        }

        var options: [String: Any] = [
            "temperature": 0.9,
            "top_p": 0.95,
            "num_predict": numPredict,
            "repeat_penalty": 1.5,
        ]
        if !model.isThinkingModel {
            options["num_ctx"] = 2048
        }

        var messageContent: [[String: Any]] = [
            ["role": "user", "content": prompt],
        ]

        if includeImage, let image {
            let base64Image = try ImageEncoder.encodeToBase64JPEG(image)
            messageContent = [
                ["role": "user", "content": prompt, "images": [base64Image]],
            ]
        }

        var payload: [String: Any] = [
            "model": model.rawValue,
            "messages": messageContent,
            "stream": false,
            "options": options,
            "keep_alive": "10m",
        ]

        if useJsonFormat {
            payload["format"] = "json"
        }

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

        print("[ScreenCommentator] Ollama raw response: \(content.prefix(500))")

        if useJsonFormat {
            return CommentParser.parseStructuredResponse(content)
        } else {
            return CommentParser.parseBatchResponse(content)
        }
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
