import Foundation
import AppKit

@MainActor
class OllamaService {
    private let baseURL = "http://localhost:11434"
    private let model = "qwen3-vl:8b"

    func generateComment(from image: CGImage) async throws -> String {
        // Convert CGImage to base64 PNG
        let nsImage = NSImage(cgImage: image, size: .zero)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw OllamaError.imageConversionFailed
        }

        let base64Image = pngData.base64EncodedString()

        // Prepare request
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "prompt": """
                You are a live stream chat commentator. Look at this screen capture and generate ONE short, casual Japanese comment (15-30 characters).
                Be encouraging, funny, or observational. Match the Twitch/Niconico stream chat vibe.
                Examples:
                - コーディング中だ！がんばれー
                - いい感じじゃん
                - wwww
                - これはむずそう
                - きたきたー

                Respond with ONLY the comment text, no explanations.
                """,
            "images": [base64Image],
            "stream": false,
            "options": [
                "temperature": 0.9,
                "top_p": 0.95
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let commentText = json?["response"] as? String else {
            throw OllamaError.invalidResponse
        }

        return commentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error
enum OllamaError: Error {
    case imageConversionFailed
    case requestFailed
    case invalidResponse
}
