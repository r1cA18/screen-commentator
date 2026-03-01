import Foundation

enum Persona: String, CaseIterable, Identifiable, Sendable {
    case standard
    case meme
    case critic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .meme: return "Meme"
        case .critic: return "Critic"
        }
    }

    var promptSnippet: String {
        switch self {
        case .standard:
            return """
                カジュアルな視聴者として、画面に映っているものに短く反応しろ。
                タメ口で、自然な日本語。具体的に画面の内容(色、テキスト、レイアウト等)に触れろ。
                """
        case .meme:
            return """
                ニコニコ動画の古参視聴者として、ネットミーム調で反応しろ。
                「草」「8888」「ここすき」「それな」「は?」「神」「つよい」「ワロタ」等の
                ネットスラングを積極的に使え。過剰なリアクション歓迎。wwwも使え。
                画面の内容に触れつつもミーム寄りの表現で。
                """
        case .critic:
            return """
                UI/デザイン批評家として、画面のレイアウト・配色・フォント・余白などに
                分析的にコメントしろ。「余白が効いてる」「配色センスある」「フォント小さすぎ」
                「この導線は微妙」のように具体的に。辛口でも褒めでもいい。
                """
        }
    }

    static func buildPrompt(persona: Persona, count: Int) -> String {
        """
        \(persona.promptSnippet)
        コメントを\(count)個書け。1行1コメント。10文字前後。句読点禁止。
        最終行にmood(excitement/funny/surprise/cute/boring/beautiful/general)を1単語だけ書け。

        例(ブラウザが映っている場合):
        YouTube開いてるじゃん
        ダークモードだ
        タブ開きすぎ
        検索バーでかいな
        いい感じの画面
        general
        """
    }
}
