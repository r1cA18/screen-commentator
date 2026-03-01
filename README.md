# Screen Commentator

macOS app that captures your screen in real-time and generates scrolling comments (like Niconico / Twitch chat overlay) using AI vision models.

## What it does

- Captures your screen every few seconds
- Sends the screenshot to a vision model (local Ollama or Google Gemini API)
- Generates short comments reacting to what's on screen
- Displays them as a transparent overlay scrolling across your screen

## Supported Providers

### Ollama (Local)

Runs entirely on your machine. No API key needed.

| Model         | Speed  | Quality                 |
| ------------- | ------ | ----------------------- |
| Qwen2.5-VL 3B | Fast   | Basic                   |
| Gemma 3 4B    | Medium | Good                    |
| Gemma 3 12B   | Slow   | Better                  |
| Qwen3-VL 8B   | Slow   | Better (thinking model) |

### Gemini (Cloud)

Uses Google's Gemini API. Requires a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey).

| Model           | Speed   | Quality | Cost          |
| --------------- | ------- | ------- | ------------- |
| 2.5 Flash Lite  | Fastest | Good    | $0.10/M input |
| 2.5 Flash       | Fast    | Great   | $0.30/M input |
| 3 Flash Preview | Medium  | Best    | $0.50/M input |

## Features

- **Provider selection**: Switch between local (Ollama) and cloud (Gemini) models
- **Ambient reactions**: Mood-matched local reactions injected between API calls (toggleable)
- **Scene change detection**: Comment volume adjusts dynamically based on screen activity
- **Text style controls**: Font size, opacity, and weight adjustable in real-time
- **Transparent overlay**: Click-through overlay that works on top of any app

## Requirements

- macOS 13.0+
- Xcode 16.0+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)
- For Ollama: [Ollama](https://ollama.com) with a vision model installed
- For Gemini: A Google AI API key (free tier available)

## Setup

```bash
git clone https://github.com/r1cka/screen-commentator.git
cd screen-commentator

# Generate Xcode project
xcodegen generate

# Open in Xcode and build (Cmd+R)
open ScreenCommentator.xcodeproj
```

Grant Screen Recording permission when prompted on first run.

### Ollama setup

```bash
ollama pull qwen2.5vl:3b
```

### Gemini setup

1. Get a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Select "Gemini (Cloud)" in the app
3. Paste your API key

## Architecture

```
ScreenCommentator/
  App.swift                          # Entry point, overlay setup
  Models/
    Comment.swift                    # Comment data model, CommentBatch
    Provider.swift                   # Provider & model enums
  Services/
    ImageEncoder.swift               # Screenshot -> JPEG base64
    OllamaService.swift              # Local Ollama API client
    GeminiService.swift              # Google Gemini API client
    ScreenCaptureService.swift       # macOS screen capture via ScreenCaptureKit
  ViewModels/
    CommentViewModel.swift           # Core logic: capture -> generate -> display
  Views/
    ContentView.swift                # Control panel UI
    OverlayWindow.swift              # Transparent scrolling comment overlay
```

## How it works

1. **Screen capture**: ScreenCaptureKit captures the display at a set interval
2. **Scene change detection**: Compares 32x32 thumbnails to estimate screen activity
3. **Comment generation**: Sends screenshot to selected AI model for short comments
4. **Mood classification**: AI returns a mood tag (excitement, funny, surprise, etc.)
5. **Ambient reactions**: Between API calls, mood-matched reactions are injected locally
6. **Overlay rendering**: Comments scroll right-to-left across a transparent overlay

## License

MIT
