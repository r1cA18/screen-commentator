# Gemini Thinking Model Integration

## Overview

Gemini 2.5/3 系の thinking model を Screen Commentator の Smart pipeline mode で使用する際に遭遇した問題と、その解決方法をまとめる。

## Background

### 元々の状態

GeminiService は `generateContent` API を呼び出し、レスポンスの `candidates[0].content.parts[0].text` からテキストを取得していた。Gemini 2.0 以前ではこれで問題なかった。

### 問題点

Gemini 2.5 Flash / 3.0 Flash Preview に切り替えたところ、Smart mode の JSON 出力が完全に壊れた。ログには以下のようなフラグメントが表示された:

```
Batch (2): ["{", "\""]
```

JSON がまったくパースできず、フォールバックの行ベースパーサーが JSON の各行を個別のコメントとして扱っていた。

## Investigation

### 1. Response parts の構造

Gemini thinking model は `parts` 配列に 2 種類のパートを返す:

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          { "thought": true, "text": "ここで画面を分析すると..." },
          {
            "text": "{\"comments\":[\"コメント1\",...],\"mood\":\"general\",\"excitement\":5}"
          }
        ]
      }
    }
  ]
}
```

`parts.first` は thinking パートを取得してしまい、JSON ではなく推論テキストを返す。

**Key point:**

- `thought: true` フラグがあるパートは推論過程
- 実際の応答は `thought` フラグがないパート

### 2. maxOutputTokens と thinking の共有予算

`maxOutputTokens: 400` を指定していたが、thinking model ではこの予算が推論トークンと出力トークンで共有される。推論に 350 トークン使うと、残り 50 トークンで JSON を出力しようとして途中で切れる:

```
{ "comments
```

### 3. thinkingConfig の仕様

Gemini 2.5 と 3.0 で thinking 制御の API が異なる:

| Model series | Parameter        | Value       | Effect            |
| ------------ | ---------------- | ----------- | ----------------- |
| Gemini 2.5   | `thinkingBudget` | `0`         | Thinking 完全無効 |
| Gemini 3.0   | `thinkingLevel`  | `"minimal"` | Thinking 最小化   |

`thinkingConfig` は `generationConfig` の中に配置する (トップレベルではない)。

## Solution

### Response extraction の修正

```swift
// Before (broken)
guard let text = responseParts?.first?["text"] as? String

// After (fixed)
guard let text = responseParts?
    .last(where: { $0["thought"] as? Bool != true })?["text"] as? String
```

`.last(where:)` を使う理由: thinking パートが先頭、response パートが末尾に来る。`.first(where:)` でも動作するが、`.last` の方が defensive。

### thinkingConfig の適用

```swift
// Models/Provider.swift
enum GeminiModel: String, CaseIterable, Identifiable, Sendable {
    case flash25Lite = "gemini-2.5-flash-lite"
    case flash25 = "gemini-2.5-flash"
    case flash3Preview = "gemini-3-flash-preview"

    var thinkingConfig: [String: Any] {
        switch self {
        case .flash25Lite, .flash25:
            return ["thinkingBudget": 0]
        case .flash3Preview:
            return ["thinkingLevel": "minimal"]
        }
    }
}
```

API リクエストの `generationConfig` に注入:

```swift
var generationConfig: [String: Any] = [
    "maxOutputTokens": 1024,
    "temperature": 0.9,
    // ...
]
generationConfig["thinkingConfig"] = model.thinkingConfig
```

### maxOutputTokens の増加

400 -> 1024 に増加。thinking 無効化後も、構造化 JSON (10+ コメント + mood + excitement) には十分なバッファが必要。

## Summary

| 問題                     | 原因                                   | 修正                                  |
| ------------------------ | -------------------------------------- | ------------------------------------- |
| JSON パース完全失敗      | `parts.first` が thinking パートを返す | `.last(where: { !thought })` に変更   |
| JSON 途中切れ            | maxOutputTokens を thinking が消費     | thinkingConfig で無効化 + 1024 に増加 |
| Gemini 2.5 vs 3.0 の差異 | thinking 制御 API が異なる             | GeminiModel.thinkingConfig で吸収     |

## Reference

- Gemini API GenerateContent: `generationConfig.thinkingConfig` で thinking 制御
- `responseMimeType: "application/json"` は thinking model でも有効 (response パートは JSON 準拠)
- thinking を完全無効化しても `parts` 配列は 1 要素 (response のみ) になるため、`.last(where:)` は安全に動作する
