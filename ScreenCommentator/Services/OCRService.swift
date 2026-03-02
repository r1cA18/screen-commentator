import Vision
import CoreGraphics

enum OCRService {
    static func recognizeText(from image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var seen = Set<String>()
                var results: [String] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty, text.count >= 2, !seen.contains(text) else { continue }
                    seen.insert(text)
                    results.append(text)
                    if results.count >= 15 { break }
                }

                continuation.resume(returning: results)
            }

            request.recognitionLevel = .fast
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[ScreenCommentator] OCR failed: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    static func formatForPrompt(_ texts: [String]) -> String {
        guard !texts.isEmpty else { return "" }
        return texts.joined(separator: ", ")
    }
}
