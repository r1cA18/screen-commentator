import Foundation
import CoreGraphics

@MainActor
final class GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func generateComments(
        from image: CGImage?,
        model: GeminiModel,
        apiKey: String,
        persona: Persona,
        count: Int,
        context: PromptContext,
        pipelineMode: PipelineMode
    ) async throws -> CommentBatch {
        let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let prompt: String
        let includeImage: Bool
        let useJsonMode: Bool

        switch pipelineMode {
        case .smart:
            prompt = Persona.buildSmartPrompt(enabledPersonas: context.enabledPersonas, count: count, context: context)
            includeImage = true
            useJsonMode = true
        case .ocrEnhanced:
            prompt = Persona.buildOCRPrompt(persona: persona, count: count, context: context)
            includeImage = false
            useJsonMode = false
        case .basic:
            prompt = Persona.buildBasicPrompt(persona: persona, count: count)
            includeImage = true
            useJsonMode = false
        }

        var parts: [[String: Any]] = []

        if includeImage, let image {
            let base64Image = try ImageEncoder.encodeToBase64JPEG(image)
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": base64Image]])
        }
        parts.append(["text": prompt])

        var generationConfig: [String: Any] = [
            "temperature": 0.9,
            "maxOutputTokens": useJsonMode ? 1024 : 400,
            "thinkingConfig": model.thinkingConfig,
        ]

        if useJsonMode {
            generationConfig["responseMimeType"] = "application/json"
        }

        let payload: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": generationConfig,
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
        let responseParts = content?["parts"] as? [[String: Any]]

        // Gemini 2.5+ thinking models return [{"thought":true,"text":"..."}, {"text":"actual output"}]
        // Use the last non-thought part
        guard let text = responseParts?
            .last(where: { $0["thought"] as? Bool != true })?["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        print("[ScreenCommentator] Gemini raw response: \(text.prefix(500))")

        if useJsonMode {
            return CommentParser.parseStructuredResponse(text)
        } else {
            return CommentParser.parseBatchResponse(text)
        }
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
