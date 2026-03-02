import Foundation

struct PromptContext: Sendable {
    let ocrText: String
    let appName: String?
    let appURL: String?
    let userActivity: String?
    let enabledPersonas: [(persona: Persona, weight: Double)]
    let recentComments: [String]

    static let empty = PromptContext(ocrText: "", appName: nil, appURL: nil, userActivity: nil, enabledPersonas: [], recentComments: [])
}

enum Persona: String, Identifiable, Sendable {
    case standard
    case meme
    case critic
    case instructor
    case barrage
    case roast

    var id: String { rawValue }

    static var allCases: [Persona] {
        [.standard, .meme, .critic, .instructor, .barrage]
    }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .meme: return "Meme"
        case .critic: return "Critic"
        case .instructor: return "Instructor"
        case .barrage: return "Barrage"
        case .roast: return "Roast"
        }
    }

    var promptSnippet: String {
        switch self {
        case .standard:
            return "カジュアルな視聴者として、画面に映っているものに短く反応しろ。タメ口で自然な日本語。画面の具体的な内容(テキスト、UI要素、色等)に触れろ。"
        case .meme:
            return "ニコニコ動画の古参視聴者として、ネットミーム調で反応しろ。「草」「8888」「ここすき」「それな」「は?」「神」「つよい」「ワロタ」等のネットスラングを使え。wwwも使え。画面の内容に触れつつもミーム寄りの表現で。"
        case .critic:
            return "UI/デザイン批評家として、画面のレイアウト・配色・フォント・余白などに分析的にコメントしろ。「余白が効いてる」「配色センスある」「フォント小さすぎ」「この導線は微妙」のように具体的に。"
        case .instructor:
            return "指示厨として、画面の操作にいちいち偉そうに口出ししろ。「そこクリックしろよ」「違うそこじゃない」「なんで閉じた」「下にスクロールしろ」「タブ多すぎ閉じろ」のように上から目線で操作指示を出しまくれ。聞かれてないのに指図するのがポイント。"
        case .barrage:
            return "弾幕コメントを書け。1~5文字の極短コメントのみ。「草」「w」「8888」「ktkr」「うぽつ」「おつ」「ここ」「神」「は?」「うお」「やば」「すご」「わかる」のような極限まで短い反応だけ。考えるな感じろ。"
        case .roast:
            return "ユーザーがサボって娯楽サイトを見ている。厳しく叱れ。「サボるな」「仕事しろ」「何見てんだ」「集中しろ」「また脱線してる」「YouTubeは後にしろ」のように直球で叱責しろ。容赦するな。ただし罵倒や人格否定はしない。"
        }
    }

    // MARK: - Mode A: Smart VLM structured prompt

    static func buildSmartPrompt(
        enabledPersonas: [(persona: Persona, weight: Double)],
        count: Int,
        context: PromptContext
    ) -> String {
        var prompt = """
        あなたは画面コメント生成AIだ。画面のスクリーンショットを見て、ニコニコ動画風のコメントを生成しろ。

        [有効なペルソナと配分]
        """

        for (persona, weight) in enabledPersonas {
            prompt += "\n- \(persona.displayName) (\(Int(weight * 100))%): \(persona.promptSnippet)"
        }

        prompt += "\n\n[コンテキスト]"
        if let appName = context.appName {
            if let url = context.appURL {
                prompt += "\nアプリ: \(appName) - \(url)"
            } else {
                prompt += "\nアプリ: \(appName)"
            }
        }
        if let activity = context.userActivity, activity != "操作なし" {
            prompt += "\nユーザー操作: \(activity)"
        }

        if !context.recentComments.isEmpty {
            let recent = context.recentComments.suffix(15).joined(separator: ", ")
            prompt += "\n\n[最近のコメント(これらと同じ内容を繰り返すな。新しい視点で書け)]\n\(recent)"
        }

        let hasBarrage = enabledPersonas.contains { $0.persona == .barrage }
        let lengthNote = hasBarrage
            ? "barrage系は1~5文字、それ以外は10文字前後"
            : "10文字前後"

        prompt += """

        \n以下のJSON形式で\(count)個のコメントを出力しろ。
        \(lengthNote)。句読点禁止。画面に映っている具体的な内容に言及しろ。
        前回と同じコメントは絶対に出すな。毎回新鮮な反応をしろ。

        {"comments":["コメント1","コメント2",...],"mood":"general","excitement":5}

        moodは excitement/funny/surprise/cute/boring/beautiful/general のいずれか。
        excitementは画面の盛り上がり度(1-10)。
        """

        return prompt
    }

    // MARK: - Mode B: OCR enhanced prompt (no image)

    static func buildOCRPrompt(persona: Persona, count: Int, context: PromptContext) -> String {
        let lengthInstruction: String
        switch persona {
        case .barrage: lengthInstruction = "1~5文字の極短コメント"
        default: lengthInstruction = "10文字前後"
        }

        var prompt = persona.promptSnippet

        if !context.ocrText.isEmpty {
            prompt += "\n\n[画面上のテキスト]\n\(context.ocrText)"
        }

        if let appName = context.appName {
            if let url = context.appURL {
                prompt += "\n\n[現在のアプリ: \(appName) - \(url)]"
            } else {
                prompt += "\n\n[現在のアプリ: \(appName)]"
            }
        }

        if let activity = context.userActivity, activity != "操作なし" {
            prompt += "\n[ユーザーの操作: \(activity)]"
        }

        prompt += "\n\n画面上のテキストを具体的に引用してコメントを\(count)個書け。1行1コメント。\(lengthInstruction)。句読点禁止。"
        prompt += "\n最終行にmood(excitement/funny/surprise/cute/boring/beautiful/general)を1単語だけ書け。"

        return prompt
    }

    // MARK: - Mode C: Basic prompt (image only, no examples)

    static func buildBasicPrompt(persona: Persona, count: Int) -> String {
        let lengthInstruction: String
        switch persona {
        case .barrage: lengthInstruction = "1~5文字の極短コメント"
        default: lengthInstruction = "10文字前後"
        }

        return """
        \(persona.promptSnippet)
        コメントを\(count)個書け。1行1コメント。\(lengthInstruction)。句読点禁止。
        画面に映っている具体的な内容に言及しろ。
        最終行にmood(excitement/funny/surprise/cute/boring/beautiful/general)を1単語だけ書け。
        """
    }
}
