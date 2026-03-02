import Foundation

enum PipelineMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case ocrEnhanced
    case basic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smart: return "Smart"
        case .ocrEnhanced: return "OCR Enhanced"
        case .basic: return "Basic"
        }
    }
}

enum CommentProvider: String, CaseIterable, Identifiable, Sendable {
    case ollama
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .gemini: return "Gemini (Cloud)"
        }
    }
}

enum GeminiModel: String, CaseIterable, Identifiable, Sendable {
    case flash25Lite = "gemini-2.5-flash-lite"
    case flash25 = "gemini-2.5-flash"
    case flash3Preview = "gemini-3-flash-preview"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash25Lite: return "2.5 Flash Lite (fastest)"
        case .flash25: return "2.5 Flash (balanced)"
        case .flash3Preview: return "3 Flash Preview (best)"
        }
    }

    var thinkingConfig: [String: Any] {
        switch self {
        case .flash25Lite, .flash25:
            return ["thinkingBudget": 0]
        case .flash3Preview:
            return ["thinkingLevel": "minimal"]
        }
    }
}
