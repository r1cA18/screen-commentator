# Screen Commentator

画面をリアルタイムにキャプチャし、AI モデルでニコニコ動画風のスクロールコメントを生成する macOS アプリ。

## デモ

https://x.com/r1ca18/status/2028052923536822643

## 何ができるか

- 数秒ごとに画面をキャプチャし、AI が画面内容を理解してコメントを生成
- 透明なオーバーレイとしてスクロール/固定コメントを表示
- 複数のペルソナ (Standard, Meme, Critic, Instructor, Barrage) を配分調整して混在可能
- 3 つのパイプラインモード (Smart / OCR Enhanced / Basic) を用途に応じて切り替え
- ブラックリスト機能で特定アプリ使用時に自動で叱責コメント (Roast)

## 注意事項

- ローカルモデル (Ollama) はマシンスペックによってレスポンスのラグが大きく変わる。MacBook Pro M4 / 64GB でもラグが目立つため、Gemini API の利用を推奨。
- Gemini (クラウド) 利用時はスクリーンショットが Google の API に送信される。画面に機密情報が映っている場合は注意。利用は自己責任。
- Smart mode は Gemini 3.0 Flash Preview との組み合わせが最もコメント品質が高い。
- PR 歓迎！

## 対応プロバイダ

### Ollama（ローカル）

完全なローカル動作

| モデル        | 速度 | 品質                   |
| ------------- | ---- | ---------------------- |
| Qwen2.5-VL 3B | 速い | 基本的                 |
| Gemma 3 4B    | 普通 | 良い                   |
| Gemma 3 12B   | 遅い | より良い               |
| Qwen3-VL 8B   | 遅い | より良い（思考モデル） |

### Gemini（クラウド）

Google の Gemini API を使用

| モデル          | 速度 | 品質 | コスト        |
| --------------- | ---- | ---- | ------------- |
| 2.5 Flash Lite  | 最速 | 良い | $0.10/M input |
| 2.5 Flash       | 速い | 優秀 | $0.30/M input |
| 3 Flash Preview | 普通 | 最高 | $0.50/M input |

## 機能

### パイプラインモード

画面情報の処理方式を 3 つのモードから選択できる。

| モード           | 方式                                                    | 推奨モデル       | 特徴                                                            |
| ---------------- | ------------------------------------------------------- | ---------------- | --------------------------------------------------------------- |
| **Smart**        | VLM に画像 + コンテキストを送信、構造化 JSON で一括生成 | Gemini 3.0 Flash | 画面の視覚的理解が最も深い。1 API 呼び出しで全 persona 分を生成 |
| **OCR Enhanced** | Vision OCR でテキスト抽出後、テキスト LLM で生成        | 任意 (VLM 不要)  | VLM 非対応モデルでも動作。テキスト参照が正確                    |
| **Basic**        | 画像 + 単一 persona プロンプト                          | 任意の VLM       | 従来方式。シンプルで安定                                        |

### ペルソナ

コメントの方向性を制御するペルソナを複数同時に有効化し、配分を調整できる。

| ペルソナ       | スタイル                                     |
| -------------- | -------------------------------------------- |
| **Standard**   | カジュアルな視聴者。画面内容に自然に反応     |
| **Meme**       | ネットミーム調。「草」「8888」「ここすき」等 |
| **Critic**     | UI/デザイン批評。余白・配色・フォントに言及  |
| **Instructor** | 指示厨。操作に上から目線で口出し             |
| **Barrage**    | 弾幕。1-5 文字の極短コメントを大量生成       |

### コア機能

- **プロバイダ切り替え**: ローカル (Ollama) とクラウド (Gemini) を切り替え可能
- **画面変化検出**: 32x32 サムネイル比較で変化量を推定し、コメント量を動的調整
- **excitement 連動**: AI が画面の盛り上がり度 (1-10) を判定し、コメント数に反映
- **コメント重複排除**: 直近 30 コメントをプロンプトに含め、同じ内容の繰り返しを抑制
- **ブラックリスト**: 特定アプリ/URL 使用時に Roast ペルソナで叱責コメントを自動生成
- **アンビエントリアクション**: API 呼び出しの合間にムードに合ったリアクションを挿入
- **テキストスタイル**: フォントサイズ、透明度、太さ、スクロール速度をリアルタイム調整
- **透明オーバーレイ**: あらゆるアプリの上に表示されるクリックスルーなオーバーレイ

### 表示

- **スクロールコメント**: 白色、右から左に流れる。速度にランダムなばらつき (0.6x-1.5x)
- **固定コメント**: 画面上部/下部に表示。ムードに応じた色付き、フォントサイズ 1.5 倍
- **レーン分散**: LRU ベースでレーンを割り当て、コメント同士の重なりを最小化

## 必要環境

- macOS 13.0+
- Xcode 16.0+（ビルド用）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（Xcode プロジェクト生成用）
- Ollama 利用時: [Ollama](https://ollama.com) + Vision モデル
- Gemini 利用時: Google AI API キー（無料枠あり）

### 権限

初回起動時に以下の権限が求められる:

| 権限             | 用途                                 | 必須                                                      |
| ---------------- | ------------------------------------ | --------------------------------------------------------- |
| 画面収録         | スクリーンショットのキャプチャ       | 必須                                                      |
| アクセシビリティ | アクティブアプリの検出               | ブラックリスト機能に必要                                  |
| 入力監視         | クリック/スクロール/タイピングの検出 | Instructor ペルソナの反応精度向上に使用。なくても動作する |

## セットアップ

```bash
git clone https://github.com/r1cA18/screen-commentator.git
cd screen-commentator

# Xcode プロジェクトを生成
xcodegen generate

# Xcode で開いてビルド (Cmd+R)
open ScreenCommentator.xcodeproj
```

### Ollama のセットアップ

```bash
ollama pull qwen2.5vl:3b
```

### Gemini のセットアップ

1. [Google AI Studio](https://aistudio.google.com/app/apikey) から無料の API キーを取得
2. アプリ内で "Gemini (Cloud)" を選択
3. API キーを貼り付け

## アーキテクチャ

```
ScreenCommentator/
  App.swift                          # エントリーポイント、オーバーレイ設定
  Models/
    Blacklist.swift                  # ブラックリスト定義 (アプリ名/URL マッチング)
    Comment.swift                    # コメントモデル、スタイル、色、CommentBatch
    Persona.swift                    # ペルソナ定義、PromptContext、プロンプトビルダー
    Provider.swift                   # プロバイダ/モデル定義、PipelineMode
    UserInputSnapshot.swift          # ユーザー入力スナップショット
  Services/
    ActiveAppMonitor.swift           # アクティブアプリ監視 (NSWorkspace 通知駆動)
    CommentParser.swift              # LLM レスポンスパーサー (JSON / 行ベース)
    GeminiService.swift              # Gemini API クライアント (thinking model 対応)
    ImageEncoder.swift               # スクリーンショット -> JPEG base64
    OCRService.swift                 # Vision framework OCR テキスト抽出
    OllamaService.swift              # ローカル Ollama API クライアント
    ScreenCaptureService.swift       # ScreenCaptureKit による画面キャプチャ
    UserInputMonitor.swift           # CGEventTap によるユーザー入力監視
  ViewModels/
    CommentViewModel.swift           # コアロジック: キャプチャ -> 生成 -> 表示
  Views/
    ContentView.swift                # コントロールパネル UI
    OverlayWindow.swift              # 透明オーバーレイ (スクロール + 固定コメント)
```

## 仕組み

### Smart mode の処理フロー

```
画面キャプチャ (ScreenCaptureKit)
  |
  +-- 画面変化検出 (32x32 サムネイル比較)
  |
  +-- コンテキスト収集
  |     +-- アクティブアプリ名/URL (ActiveAppMonitor)
  |     +-- ユーザー操作 (UserInputMonitor)
  |     +-- 直近コメント履歴 (重複排除用)
  |
  +-- ブラックリスト判定
  |     +-- 該当 -> Roast ペルソナ強制
  |     +-- 非該当 -> 通常ペルソナ配分
  |
  +-- プロンプト構築 (全ペルソナ配分 + コンテキスト)
  |
  +-- LLM 呼び出し (画像 + プロンプト -> 構造化 JSON)
  |     {"comments": [...], "mood": "...", "excitement": N}
  |
  +-- パース (CommentParser.parseStructuredResponse)
  |
  +-- コメント表示
        +-- スタイル割り当て (scroll / top / bottom)
        +-- レーン割り当て (LRU ベース分散)
        +-- 速度ランダム化 (0.6x-1.5x)
        +-- 時間差リリース
```

### OCR Enhanced mode

Smart mode との違いは、画像を LLM に送信しない点。代わりに Vision framework の `VNRecognizeTextRequest` で画面テキストを抽出し、テキストのみで LLM にコメント生成させる。VLM 非対応のモデルでも動作する。

## ドキュメント

技術的な設計判断や実装の詳細は `docs/` を参照。

| ドキュメント                                                                          | 内容                                                                                                                 |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [Pipeline Mode Architecture](docs/decisions/0001-pipeline-mode-architecture.md)       | 3 つのパイプラインモード (Smart/OCR/Basic) の設計判断。検討した選択肢の比較と採用理由                                |
| [Gemini Thinking Model Integration](docs/guides/gemini-thinking-model-integration.md) | Gemini 2.5/3 系 thinking model の response parts 構造、thinkingConfig による制御、maxOutputTokens 共有問題の解決方法 |
| [Session Log: Phase 2](docs/sessions/2026-03-02-phase2-pipeline-modes.md)             | Phase 2 実装の全作業ログ。変更ファイル一覧、学んだこと、未完了タスク                                                 |

## License

MIT
