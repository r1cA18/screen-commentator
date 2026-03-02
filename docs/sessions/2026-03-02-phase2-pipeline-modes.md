# Session Log: 2026-03-02 - Phase 2 Pipeline Modes Implementation

## Summary

Phase 2 としてパイプラインモード (Smart / OCR Enhanced / Basic) の実装、Smart mode の Gemini thinking model 対応バグ修正、表示改善 (レーン分散・速度ばらつき・固定コメントサイズ)、コメント重複排除、post-review による品質修正を完了した。

## やったこと

- [x] Phase 2-1: Blacklist バグ修正 + ActiveAppMonitor イベント駆動化
- [x] Phase 2-2: OCRService 新規作成 (Vision framework)
- [x] Phase 2-3: UserInputMonitor 新規作成 (CGEventTap)
- [x] Phase 2-4: パイプラインモード統合 (Smart / OCR Enhanced / Basic)
- [x] Phase 2-5: 表示改善 (色・サイズ・速度)
- [x] Phase 2-6: OCR キャッシュ + excitement 連動コメント数
- [x] Phase 2-7: ContentView 設定 UI (Pipeline picker)
- [x] Smart mode JSON パース失敗の修正 (Gemini thinking model 対応)
- [x] コメント重複排除 (recentCommentTexts バッファ)
- [x] レーン分散改善 (LRU ベース)
- [x] 固定コメントサイズ拡大 (1.5x)
- [x] スクロール速度ばらつき拡大 (0.6-1.5)
- [x] mood ベースの色割り当て
- [x] Post-review: 3 並列レビュー (Opus / Sonnet / Codex) 実施・修正
- [ ] TCC 権限リセット問題 (self-signed certificate が必要、コード修正では対応不可)

## 学んだこと

### Gemini thinking model のレスポンス構造

Gemini 2.5/3 系の thinking model は `parts` 配列に `[{thought:true, text:"推論"}, {text:"実際の出力"}]` という構造で返す。`parts.first` ではなく `.last(where: { $0["thought"] as? Bool != true })` で非 thought パートを取得する必要がある。

さらに `maxOutputTokens` は thinking tokens と共有されるため、小さい値 (400) だと思考で予算を使い切り、実際の出力が途中で切れる。解決策は `thinkingConfig` で thinking を無効化/最小化すること:

- Gemini 2.5 系: `"thinkingBudget": 0`
- Gemini 3 系: `"thinkingLevel": "minimal"`

### CGEventTap の Unmanaged メモリ管理

`listenOnly` の event tap コールバックで `Unmanaged.passRetained(event)` を使うと、全システムイベント (マウス移動、キー入力等) ごとに retain count が増加し、メモリリークになる。`passUnretained` が正解。一般に、所有権を取得する必要がないコールバックでは `passUnretained` を使う。

### macOS TCC 権限とコード署名

macOS の TCC (Transparency, Consent, and Control) は cdhash でアプリを識別する。ad-hoc 署名 (`-` でサイン) はビルドごとにハッシュが変わるため、毎回権限再設定が必要。self-signed certificate で署名すれば cdhash が安定し、権限が持続する。

## 調査したこと

| トピック                              | 結果                                                              |
| ------------------------------------- | ----------------------------------------------------------------- |
| Gemini thinking model response format | `parts` 配列に thought と response が混在。`.last(where:)` で分離 |
| maxOutputTokens と thinking の関係    | 共有予算。thinkingConfig で thinking を無効化/最小化する          |
| CGEventTap メモリ管理                 | listenOnly では `passUnretained` を使う                           |
| TCC 権限の永続化                      | self-signed certificate による一貫した署名が必要                  |
| NSRegularExpression の最適化          | `static let` で事前コンパイルし、呼び出しごとの再コンパイルを回避 |

## 変更したファイル

### 新規作成

- `Models/Blacklist.swift` - Blacklist enum (アプリ名/URL マッチング)
- `Models/UserInputSnapshot.swift` - ユーザー入力のスナップショット構造体
- `Services/ActiveAppMonitor.swift` - イベント駆動型アクティブアプリ監視
- `Services/OCRService.swift` - Vision framework による画面テキスト抽出
- `Services/UserInputMonitor.swift` - CGEventTap によるユーザー入力監視

### 変更

- `Models/Comment.swift` - CommentStyle, CommentColor, speedMultiplier, CommentBatch.excitement 追加
- `Models/Persona.swift` - PromptContext (recentComments 含む), 3 種のプロンプトビルダー追加
- `Models/Provider.swift` - PipelineMode enum, GeminiModel.thinkingConfig 追加
- `Services/CommentParser.swift` - parseStructuredResponse, cached regex, JSON fragment フィルタ追加
- `Services/GeminiService.swift` - パイプラインモード対応, thinkingConfig, thinking パート分離
- `Services/OllamaService.swift` - パイプラインモード対応, num_predict 増加
- `ViewModels/CommentViewModel.swift` - パイプライン統合, 重複排除, LRU レーン分散
- `Views/ContentView.swift` - Pipeline mode picker UI 追加
- `Views/OverlayWindow.swift` - 固定コメント 1.5x, 速度ばらつき拡大

### Post-review で修正

- `Services/UserInputMonitor.swift` - `passRetained` -> `passUnretained` (メモリリーク修正)
- `Services/CommentParser.swift` - NSRegularExpression を `static let` に変更
- `ViewModels/CommentViewModel.swift` - 固定コメントのゴースト問題修正 (scrollCommentDuration / fixedCommentDuration 分離)

## 次回への引き継ぎ

### 未完了タスク

- [ ] TCC 権限永続化: self-signed certificate を作成し、Xcode の Code Signing Identity に設定する
- [ ] Ollama での Smart mode テスト: ローカルモデルの JSON 構造化出力の安定性確認
- [ ] excitement 連動のチューニング: コメント数 multiplier の適切な値を実運用で調整

### 注意点

- Gemini API の thinkingConfig は `generationConfig` の中に配置する (トップレベルではない)
- Smart mode では `responseMimeType: "application/json"` を使うが、Ollama では `"format": "json"` (ベストエフォート)
- CGEventTap は Input Monitoring 権限が必要。ない場合は graceful degradation (入力情報なしで動作)

## 関連ドキュメント

- [Pipeline Mode Architecture Decision](../decisions/0001-pipeline-mode-architecture.md)
- [Gemini Thinking Model Integration Guide](../guides/gemini-thinking-model-integration.md)
