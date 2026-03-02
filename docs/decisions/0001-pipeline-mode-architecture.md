# 0001. Pipeline Mode Architecture

## Status

Accepted

## Date

2026-03-02

## Context

Screen Commentator はスクリーンショットを LLM に送り、ニコニコ動画風コメントを生成するアプリ。Phase 1 では単一のパイプライン (画像 + persona プロンプト) で動作していたが、以下の問題があった:

1. **画面理解の浅さ**: コメントが汎用的すぎる (「おー」「すごい」等)。画面の具体的な内容に言及しない
2. **プロンプト例への依存**: ハードコードされた例文 (「YouTube開いてるじゃん」等) が出力を支配
3. **モデル制約**: VLM (Vision Language Model) でないモデルでは画像を処理できない
4. **1 persona = 1 API 呼び出し**: 複数 persona を有効にすると API 呼び出し回数が線形増加

これらを解決するため、用途に応じて切り替え可能な複数のパイプラインモードが必要になった。

## Decision

3 つのパイプラインモードを実装し、ユーザーが設定 UI で切り替えられるようにした。

```swift
enum PipelineMode: String, CaseIterable, Identifiable, Sendable {
    case smart        // Mode A: Smart VLM
    case ocrEnhanced  // Mode B: OCR + Text LLM
    case basic        // Mode C: Legacy
}
```

### Mode A: Smart VLM (構造化ワンショット)

1 回の API 呼び出しで全 persona 分のコメントを構造化 JSON として生成。

- 入力: スクリーンショット画像 + 全 persona 配分 + コンテキスト (アプリ名, URL, ユーザー操作, 最近のコメント)
- 出力: `{"comments": [...], "mood": "...", "excitement": N}`
- Gemini: `responseMimeType: "application/json"` で JSON 強制
- Ollama: `"format": "json"` でベストエフォート

### Mode B: OCR Enhanced (テキストのみ)

Vision framework の OCR でテキスト抽出後、画像なしでテキスト LLM に送る。

- 入力: OCR テキスト + コンテキスト (画像送信なし)
- 出力: 行ベースのコメント + mood
- VLM 不要なので、テキスト専用モデルや軽量モデルでも動作

### Mode C: Basic (従来互換)

Phase 1 の動作を維持。画像 + 単一 persona プロンプト。

## Considered Options

### Option A: 単一パイプライン改善

既存パイプラインのプロンプトだけを改善する。

**Pros:**

- 実装コストが最小
- コードの複雑性が増えない

**Cons:**

- VLM 非対応モデルを使えない
- 複数 persona の同時利用で API 呼び出しが増える
- 画面理解の深さがモデル性能に完全依存

### Option B: 3 モード切り替え (採用)

Smart / OCR Enhanced / Basic の 3 モードを実装し、ユーザーが選択する。

**Pros:**

- モデルの能力に合わせて最適なモードを選択できる
- Smart mode で 1 API 呼び出しに統合でき、コスト削減
- OCR mode で VLM 不要、テキストモデルでも動作
- Basic mode で後方互換性を維持

**Cons:**

- コード複雑性が増加 (3 つのコードパス)
- ユーザーが適切なモードを選ぶ必要がある
- テスト・検証の工数が 3 倍

### Option C: 自動モード選択

モデルの capability を検出して自動的にモードを切り替える。

**Pros:**

- ユーザーが選ぶ必要がない
- 常に最適なモードが使われる

**Cons:**

- モデル capability の検出が困難 (特に Ollama のカスタムモデル)
- 誤検出時のフォールバックが複雑
- 実装コストが高い

## Consequences

### Positive

- Gemini 3.0 Flash + Smart mode で画面内容に具体的に言及するコメントが生成されるようになった
- 1 API 呼び出しで全 persona 分を処理するため、レイテンシとコストが改善
- OCR mode により VLM 非対応の軽量モデルでも使用可能に
- `PromptContext` 構造体により、コンテキスト情報 (アプリ名, URL, ユーザー操作, 最近のコメント) を統一的に管理

### Negative

- `CommentViewModel.processCapture()` のコードパスが 3 つに分岐し、複雑性が増加
- Smart mode の JSON パーシングは LLM の出力品質に依存 (フォールバックとして line-based parser を維持)

### Future

- モデルのプロファイルに基づく自動モード推薦を将来的に検討
- Smart mode の構造化出力にコメントスタイル (scroll/top/bottom) や色の指定を含める拡張も可能
