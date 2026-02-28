# Screen Commentator

Live stream-style comment overlay powered by local LLM.

## Overview

Monitors your screen and generates Twitch/Niconico-style comments that scroll across the display using a local LLM (qwen3-vl:8b via Ollama).

## Architecture

- **Screen Capture**: ScreenCaptureKit (macOS 12.3+) captures display every 5 seconds
- **LLM**: Ollama (qwen3-vl:8b) analyzes screen and generates Japanese comments
- **Comment Flow**: Comments queue and release over 5 seconds, scrolling right-to-left
- **Overlay**: Transparent, always-on-top window with click-through

## Requirements

- macOS 13.0+
- Xcode 16.0+
- XcodeGen
- Ollama with qwen3-vl:8b model

## Setup

```bash
# Install Ollama model
ollama pull qwen3-vl:8b

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project ScreenCommentator.xcodeproj -scheme ScreenCommentator build

# Run
open build/Release/ScreenCommentator.app
```

## Permissions

On first run, grant Screen Recording permission in System Preferences > Privacy & Security.

## Technical Details

- Capture interval: 5 seconds
- Comment release: 1 comment per second
- Animation duration: 5 seconds (right to left)
- LLM temperature: 0.9 (high creativity)
- Target comment length: 15-30 characters

## Directory Structure

```
ScreenCommentator/
├── App.swift                      # Entry point
├── Models/
│   ├── Comment.swift              # Comment data model
│   └── CommentQueue.swift         # Queue management
├── Services/
│   ├── ScreenCaptureService.swift # ScreenCaptureKit wrapper
│   └── OllamaService.swift        # Ollama API client
├── ViewModels/
│   └── CommentViewModel.swift     # Business logic
└── Views/
    ├── ContentView.swift          # Control UI
    └── OverlayWindow.swift        # Comment overlay
```
