import Foundation
import SwiftUI
import AppKit
import CoreGraphics

@MainActor
final class CommentViewModel: ObservableObject {
    @Published var activeComments: [Comment] = []
    @Published var isRunning = false
    @Published var statusMessage = ""
    @Published var commentCount = 0

    // Provider & model selection
    @Published var selectedProvider: CommentProvider = .ollama
    @Published var selectedOllamaModel: OllamaModel = .qwen25vl_3b
    @Published var selectedGeminiModel: GeminiModel = .flash25Lite
    @Published var geminiApiKey: String = "" {
        didSet { UserDefaults.standard.set(geminiApiKey, forKey: "geminiApiKey") }
    }

    // Persona
    @Published var personaEnabled: [Persona: Bool] = [
        .standard: true,
        .meme: true,
        .critic: false,
    ]
    @Published var personaWeights: [Persona: Double] = [
        .standard: 0.6,
        .meme: 0.3,
        .critic: 0.1,
    ]

    // Generation
    @Published var baseCommentCount: Int = 5

    // Text style
    @Published var fontSize: CGFloat = 40
    @Published var textOpacity: Double = 1.0
    @Published var fontWeightBold: Bool = true

    static let laneHeight: CGFloat = 44
    static let topMargin: CGFloat = 30

    private let captureService = ScreenCaptureService()
    private let ollamaService = OllamaService()
    private let geminiService = GeminiService()
    private let captureInterval: TimeInterval = 4.0
    private let commentDuration: TimeInterval = 7.0
    private let maxActiveComments = 30

    var laneCount: Int {
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        return max(1, Int((screenHeight - Self.topMargin) / Self.laneHeight))
    }

    private var scheduledReleases: [(text: String, releaseAt: Date)] = []
    private var releaseTimer: Timer?
    private var captureTask: Task<Void, Never>?

    // Excitement tracking
    private var changeLevel: Double = 0.05
    private var lastMood: String = "general"
    private var previousThumbnail: [UInt8]?

    init() {
        self.geminiApiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    }

    // MARK: - Public

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        commentCount = 0

        switch selectedProvider {
        case .ollama:
            statusMessage = "Connecting to Ollama..."
            let ready = await ollamaService.ensureRunning()
            guard ready else {
                statusMessage = "Ollama not found. Install from ollama.com"
                isRunning = false
                return
            }
        case .gemini:
            guard !geminiApiKey.isEmpty else {
                statusMessage = "Gemini API key is required"
                isRunning = false
                return
            }
        }

        statusMessage = "Starting screen capture..."
        startReleaseTimer()

        let provider = selectedProvider
        let ollamaModel = selectedOllamaModel
        let geminiModel = selectedGeminiModel
        let apiKey = geminiApiKey

        captureTask = Task.detached { [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.captureService.startCapturing(interval: self.captureInterval)
                await MainActor.run { self.statusMessage = "Running - waiting for first capture..." }

                for await image in stream {
                    let isRunning = await self.isRunning
                    guard isRunning else { break }
                    await self.processCapture(
                        image,
                        provider: provider,
                        ollamaModel: ollamaModel,
                        geminiModel: geminiModel,
                        apiKey: apiKey
                    )
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Capture error: \(error.localizedDescription)"
                    self.isRunning = false
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        statusMessage = "Stopped"

        captureTask?.cancel()
        captureTask = nil
        captureService.stopCapturing()

        releaseTimer?.invalidate()
        releaseTimer = nil

        activeComments.removeAll()
        scheduledReleases.removeAll()
        previousThumbnail = nil
        lastMood = "general"
        changeLevel = 0.05
    }

    func addTestComment() {
        let texts = ["test", "8888", "www", "ktkr"]
        let text = texts.randomElement()!
        let comment = Comment(text: text, lane: Int.random(in: 0..<laneCount))
        activeComments.append(comment)
    }

    // MARK: - Persona Selection

    func selectPersona() -> Persona {
        let enabled = Persona.allCases.filter { personaEnabled[$0] == true }
        guard !enabled.isEmpty else { return .standard }

        let totalWeight = enabled.reduce(0.0) { $0 + (personaWeights[$1] ?? 0) }
        guard totalWeight > 0 else { return enabled.randomElement()! }

        let roll = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for persona in enabled {
            cumulative += personaWeights[persona] ?? 0
            if roll < cumulative { return persona }
        }
        return enabled.last!
    }

    // MARK: - Excitement

    private func computeExcitementScore(changeLevel: Double, mood: String) -> Double {
        let moodBonus: Double
        switch mood {
        case "excitement", "surprise": moodBonus = 0.15
        case "funny", "beautiful": moodBonus = 0.08
        case "general", "cute": moodBonus = 0.04
        case "boring": moodBonus = 0.0
        default: moodBonus = 0.04
        }
        return changeLevel * 0.6 + moodBonus * 0.4
    }

    private func commentCountForExcitement(_ score: Double) -> Int {
        let base = baseCommentCount
        let delta: Int
        if score < 0.02 {
            delta = -2
        } else if score < 0.05 {
            delta = -1
        } else if score < 0.10 {
            delta = 0
        } else if score < 0.15 {
            delta = 1
        } else {
            delta = 2
        }
        return max(1, base + delta)
    }

    // MARK: - Private

    private func processCapture(
        _ image: CGImage,
        provider: CommentProvider,
        ollamaModel: OllamaModel,
        geminiModel: GeminiModel,
        apiKey: String
    ) async {
        let thumbnail = createThumbnail(image)
        let change = computeChangeLevel(current: thumbnail)
        let persona = await self.selectPersona()
        let excitement = computeExcitementScore(changeLevel: change, mood: lastMood)
        let count = commentCountForExcitement(excitement)

        await MainActor.run {
            self.changeLevel = change
            self.previousThumbnail = thumbnail
        }

        let modelName: String
        switch provider {
        case .ollama: modelName = ollamaModel.displayName
        case .gemini: modelName = geminiModel.displayName
        }

        await MainActor.run {
            statusMessage = "Generating \(count) comments (\(modelName), \(persona.displayName))..."
        }

        do {
            let batch: CommentBatch
            switch provider {
            case .ollama:
                batch = try await ollamaService.generateComments(
                    from: image, model: ollamaModel, persona: persona, count: count
                )
            case .gemini:
                batch = try await geminiService.generateComments(
                    from: image, model: geminiModel, apiKey: apiKey, persona: persona, count: count
                )
            }

            await MainActor.run {
                self.lastMood = batch.mood
                self.scheduleCommentRelease(batch.comments)
                self.commentCount += batch.comments.count
                self.statusMessage = "Running - \(modelName) | \(persona.displayName) | mood: \(batch.mood) (\(self.commentCount) comments)"
            }
            print("[ScreenCommentator] Batch (\(batch.comments.count)): \(batch.comments) mood=\(batch.mood) persona=\(persona.rawValue) change=\(String(format: "%.3f", change))")
        } catch is CancellationError {
            print("[ScreenCommentator] Request cancelled")
        } catch {
            print("[ScreenCommentator] Generation failed: \(error.localizedDescription)")
            await MainActor.run {
                statusMessage = "Running (generation error, retrying...)"
            }
        }
    }

    // MARK: - Scheduled Release

    private func scheduleCommentRelease(_ comments: [String]) {
        guard !comments.isEmpty else { return }
        let interval = captureInterval / Double(comments.count + 1)
        let now = Date()

        for (i, text) in comments.enumerated() {
            let jitter = Double.random(in: -0.3...0.3) * interval
            let delay = interval * Double(i + 1) + jitter
            scheduledReleases.append((text: text, releaseAt: now.addingTimeInterval(delay)))
        }

        scheduledReleases.sort { $0.releaseAt < $1.releaseAt }
    }

    private func startReleaseTimer() {
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.releaseScheduled()
            }
        }
    }

    private func releaseScheduled() {
        let now = Date()
        activeComments.removeAll { now.timeIntervalSince($0.timestamp) > commentDuration }

        while !scheduledReleases.isEmpty,
              activeComments.count < maxActiveComments,
              scheduledReleases.first!.releaseAt <= now {
            let entry = scheduledReleases.removeFirst()
            let comment = Comment(text: entry.text, lane: Int.random(in: 0..<laneCount))
            activeComments.append(comment)
        }
    }

    // MARK: - Scene Change Detection

    private func createThumbnail(_ image: CGImage) -> [UInt8] {
        let size = 32
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return pixels
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        return pixels
    }

    private func computeChangeLevel(current: [UInt8]) -> Double {
        guard let previous = previousThumbnail, previous.count == current.count, !current.isEmpty else {
            return 0.05
        }

        var totalDiff: Int = 0
        let pixelCount = current.count / 4

        for i in 0..<pixelCount {
            let base = i * 4
            let dr = abs(Int(current[base]) - Int(previous[base]))
            let dg = abs(Int(current[base + 1]) - Int(previous[base + 1]))
            let db = abs(Int(current[base + 2]) - Int(previous[base + 2]))
            totalDiff += dr + dg + db
        }

        let maxDiff = pixelCount * 3 * 255
        return Double(totalDiff) / Double(maxDiff)
    }
}
