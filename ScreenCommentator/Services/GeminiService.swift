import Foundation
import CoreGraphics

@MainActor
final class GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func generateComments(
        from image: CGImage,
        model: GeminiModel,
        apiKey: String,
        persona: Persona,
        count: Int
    ) async throws -> CommentBatch {
        let base64Image = try ImageEncoder.encodeToBase64JPEG(image)

        let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let prompt = Persona.buildPrompt(persona: persona, count: count)

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

        return CommentParser.parseBatchResponse(text)
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
