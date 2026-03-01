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

    // Ambient reactions
    @Published var ambientEnabled = true

    // Text style
    @Published var fontSize: CGFloat = 28
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

    private var pendingComments: [String] = []
    private var releaseTimer: Timer?
    private var captureTask: Task<Void, Never>?

    // Mood-based ambient system
    private var currentMood = "general"
    private var changeLevel: Double = 0.05
    private var previousThumbnail: [UInt8]?
    private var ambientTimer: Timer?

    private let reactionPool: [String: [String]] = [
        "excitement": [
            "すげえ", "やば", "えぐい", "つよ", "神", "マジか", "おおお",
            "きたああ", "はんぱねえ", "レベチ", "化け物", "天才", "やばすぎ",
            "半端ない", "すご", "つええ", "ガチ", "さすが", "最強",
        ],
        "funny": [
            "wwww", "草", "ワロタ", "おもろ", "笑うわ", "腹痛い", "草生える",
            "それは草", "くさ", "ちょwww", "だめだwww", "耐えられん", "声出た",
            "吹いた", "やめろwww", "ずるい", "卑怯", "ツボった", "もう無理www",
        ],
        "surprise": [
            "は？", "えっ", "なにこれ", "まじか", "え待って", "うそだろ",
            "嘘やん", "マ？", "えぇ", "ファッ", "想定外", "予想外",
            "そうはならんやろ", "ちょっと待って", "えええ", "これまじ？",
        ],
        "cute": [
            "かわいい", "かわ", "尊い", "推せる", "天使", "守りたい",
            "てぇてぇ", "癒し", "すこ", "好き", "最高にかわいい",
            "ぬくもり", "かわいすぎ", "愛しい", "無理かわいい",
        ],
        "boring": [
            "...", "眠い", "まだ？", "はよ", "何してんの", "うーん",
            "微妙", "しーん", "おーい", "動けー", "zzz", "寝る",
            "退屈", "まだかな", "長い",
        ],
        "beautiful": [
            "きれい", "美しい", "エモい", "映え", "やばきれい", "景色やば",
            "綺麗すぎ", "神画質", "芸術", "画力", "これは美しい", "最高",
            "やばい綺麗", "鳥肌", "泣ける",
        ],
        "general": [
            "8888", "おつ", "うぽつ", "わかる", "それな", "なるほど",
            "たしかに", "せやな", "ほんそれ", "わかりみ", "見てる",
            "きた", "ここすき", "いいね", "おお", "へー", "ふむ",
        ],
    ]

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
        startTimers()

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
        ambientTimer?.invalidate()
        ambientTimer = nil

        activeComments.removeAll()
        pendingComments.removeAll()
        previousThumbnail = nil
        currentMood = "general"
        changeLevel = 0.05
    }

    func addTestComment() {
        let pool = reactionPool["general"] ?? ["test"]
        let text = pool.randomElement()!
        let comment = Comment(text: text, lane: Int.random(in: 0..<laneCount))
        activeComments.append(comment)
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
        await MainActor.run {
            self.changeLevel = change
            self.previousThumbnail = thumbnail
        }

        let count: Int
        if change < 0.02 {
            count = 2
        } else if change < 0.08 {
            count = 4
        } else {
            count = 6
        }

        let modelName: String
        switch provider {
        case .ollama: modelName = ollamaModel.displayName
        case .gemini: modelName = geminiModel.displayName
        }

        await MainActor.run {
            statusMessage = "Generating \(count) comments (\(modelName))..."
        }

        do {
            let batch: CommentBatch
            switch provider {
            case .ollama:
                batch = try await ollamaService.generateComments(from: image, model: ollamaModel, count: count)
            case .gemini:
                batch = try await geminiService.generateComments(from: image, model: geminiModel, apiKey: apiKey, count: count)
            }

            await MainActor.run {
                self.currentMood = batch.mood
                self.pendingComments.append(contentsOf: batch.comments)
                self.commentCount += batch.comments.count
                self.statusMessage = "Running - \(modelName) | mood: \(batch.mood) (\(self.commentCount) comments)"
            }
            print("[ScreenCommentator] Batch (\(batch.comments.count)): \(batch.comments) mood=\(batch.mood) change=\(String(format: "%.3f", change))")
        } catch is CancellationError {
            print("[ScreenCommentator] Request cancelled")
        } catch {
            print("[ScreenCommentator] Generation failed: \(error.localizedDescription)")
            await MainActor.run {
                statusMessage = "Running (generation error, retrying...)"
            }
        }
    }

    private func startTimers() {
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.releaseNext()
            }
        }

        ambientTimer?.invalidate()
        ambientTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.injectAmbient()
            }
        }
    }

    private func releaseNext() {
        let now = Date()
        activeComments.removeAll { now.timeIntervalSince($0.timestamp) > commentDuration }

        if activeComments.count < maxActiveComments, !pendingComments.isEmpty {
            let text = pendingComments.removeFirst()
            let comment = Comment(text: text, lane: Int.random(in: 0..<laneCount))
            activeComments.append(comment)
        }
    }

    private func injectAmbient() {
        guard isRunning else { return }
        guard ambientEnabled else { return }
        guard activeComments.count < maxActiveComments else { return }

        let probability: Double
        if changeLevel < 0.02 {
            probability = 0.1
        } else if changeLevel < 0.08 {
            probability = 0.25
        } else {
            probability = 0.8
        }

        guard Double.random(in: 0...1) < probability else { return }

        let pool = reactionPool[currentMood] ?? reactionPool["general"]!
        let text = pool.randomElement()!
        let comment = Comment(text: text, lane: Int.random(in: 0..<laneCount))
        activeComments.append(comment)
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
