# Screen Commentator

画面をリアルタイムにキャプチャし、AI Vision モデルでニコニコ風のスクロールコメントを生成する macOS アプリ。

## デモ

https://x.com/r1ca18/status/2028052923536822643

## 何ができるか

- 数秒ごとに画面をキャプチャ
- スクリーンショットを Vision モデル（ローカル Ollama / Google Gemini API）に送信
- 画面の内容に対する短いコメントを生成
- 透明なオーバーレイとして画面上をスクロール表示

## 注意事項

- ローカルモデル（Ollama）はマシンスペックによってレスポンスのラグが大きく変わる。MacBook Pro M4 / メモリ 64GB でもラグが目立ったため、10 秒程度のレスポンスを求める場合は Gemini API の利用を推奨
- Gemini（クラウド）利用時はスクリーンショットが Google の API に送信される。画面に機密情報が映っている場合は注意。利用は自己責任で
- 現状は軽量モデル（Qwen3, Gemini 2.5 等）を使用しており、コメント品質には改善の余地がある
- PR 歓迎

## 対応プロバイダ

### Ollama（ローカル）

完全にローカルで動作。API キー不要。

| モデル        | 速度 | 品質                   |
| ------------- | ---- | ---------------------- |
| Qwen2.5-VL 3B | 速い | 基本的                 |
| Gemma 3 4B    | 普通 | 良い                   |
| Gemma 3 12B   | 遅い | より良い               |
| Qwen3-VL 8B   | 遅い | より良い（思考モデル） |

### Gemini（クラウド）

Google の Gemini API を使用。[Google AI Studio](https://aistudio.google.com/app/apikey) から無料の API キーを取得可能。

| モデル          | 速度 | 品質 | コスト        |
| --------------- | ---- | ---- | ------------- |
| 2.5 Flash Lite  | 最速 | 良い | $0.10/M input |
| 2.5 Flash       | 速い | 優秀 | $0.30/M input |
| 3 Flash Preview | 普通 | 最高 | $0.50/M input |

## 機能

- **プロバイダ切り替え**: ローカル（Ollama）とクラウド（Gemini）を切り替え可能
- **アンビエントリアクション**: API 呼び出しの合間にムードに合ったローカル生成のリアクションを挿入（ON/OFF 可能）
- **画面変化検出**: 画面の変化量に応じてコメント量を動的に調整
- **テキストスタイル調整**: フォントサイズ、透明度、太さをリアルタイムに変更可能
- **透明オーバーレイ**: あらゆるアプリの上に表示されるクリックスルーなオーバーレイ

## 必要環境

- macOS 13.0+
- Xcode 16.0+（ビルド用）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（Xcode プロジェクト生成用）
- Ollama 利用時: [Ollama](https://ollama.com) + Vision モデルのインストール
- Gemini 利用時: Google AI API キー（無料枠あり）

## セットアップ

```bash
git clone https://github.com/r1cka/screen-commentator.git
cd screen-commentator

# Xcode プロジェクトを生成
xcodegen generate

# Xcode で開いてビルド (Cmd+R)
open ScreenCommentator.xcodeproj
```

初回起動時に画面収録の権限を求められるので許可する。

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
    Comment.swift                    # コメントデータモデル、CommentBatch
    Provider.swift                   # プロバイダ・モデル定義
  Services/
    ImageEncoder.swift               # スクリーンショット -> JPEG base64
    OllamaService.swift              # ローカル Ollama API クライアント
    GeminiService.swift              # Google Gemini API クライアント
    ScreenCaptureService.swift       # ScreenCaptureKit による画面キャプチャ
  ViewModels/
    CommentViewModel.swift           # コアロジック: キャプチャ -> 生成 -> 表示
  Views/
    ContentView.swift                # コントロールパネル UI
    OverlayWindow.swift              # 透明スクロールコメントオーバーレイ
```

## 仕組み

1. **画面キャプチャ**: ScreenCaptureKit で一定間隔にディスプレイをキャプチャ
2. **画面変化検出**: 32x32 サムネイルを比較して画面の変化量を推定
3. **コメント生成**: スクリーンショットを選択した AI モデルに送信し短いコメントを生成
4. **ムード分類**: AI がムードタグ（excitement, funny, surprise 等）を返す
5. **アンビエントリアクション**: API 呼び出しの合間にムードに合ったリアクションをローカル生成
6. **オーバーレイ描画**: コメントが透明オーバーレイ上を右から左にスクロール

## License

MIT
