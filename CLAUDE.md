# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## LoopLifter - AI Sample Pack Generator

### Project Overview
LoopLifter is an AI-powered sample extraction tool that analyzes any audio file, separates it into stems, and automatically extracts production-ready samples (loops, hits, phrases). Part of the "Lo" Suite alongside LoOptimizer.

### Current Status
**Phase:** Initial Development
**Platform:** macOS 14.0+
**Language:** Swift 5.9+
**Framework:** SwiftUI + AVFoundation + Demucs

### Architecture

```
LoopLifter/
├── LoopLifterApp.swift          # App entry point
├── ContentView.swift            # Main view with state machine
├── Core/
│   ├── Analysis/
│   │   ├── SelfSimilarityAnalyzer.swift  # Loop detection
│   │   ├── NoveltyDetector.swift         # Fill/transition detection
│   │   └── HitIsolator.swift             # Single hit extraction
│   ├── Extraction/
│   │   └── (per-stem extractors)
│   ├── Export/
│   │   └── (format exporters)
│   └── Models/
│       └── ExtractedSample.swift         # Core data model
├── Views/
│   ├── DropZoneView.swift       # Drag-and-drop interface
│   ├── ResultsView.swift        # Sample results display
│   └── SettingsView.swift       # App preferences
└── Shared/
    └── (shared with LoOptimizer via LoAudioKit)
```

### Key Algorithms

1. **Self-Similarity Matrix** - For loop detection
   - Compute features (MFCC, spectral) per beat
   - Build NxN similarity matrix
   - Find diagonal patterns = repeating loops

2. **Novelty Detection** - For fills/transitions
   - Compute spectral flux over time
   - Find peaks in novelty curve
   - Peaks at phrase boundaries = fills

3. **Hit Isolation** - For single hits
   - Find isolated onsets (silence before/after)
   - Classify by spectral content (kick/snare/hat)

### Related Projects
- **LoOptimizer** - Remix studio (uses extracted samples)
- **LoAudioKit** - Shared Swift package (to be extracted)

### Development Guidelines

#### Code Style
- Use Swift's @Observable macro for state
- Prefer async/await for audio operations
- Keep analysis algorithms in Core/Analysis
- UI components in Views/

#### Testing
- Test analysis algorithms with diverse audio
- Validate loop detection on known songs
- Check hit classification accuracy

#### Performance
- Use Accelerate framework for DSP
- Lazy loading for large audio files
- Background processing for analysis

### Shared Components (from LoOptimizer)
These will be extracted to LoAudioKit:
- StemSeparator (Demucs integration)
- AubioAnalyzer (beat/tempo detection)
- AudioEngine (playback)
- WaveformGenerator

### Next Steps
1. Set up Xcode project with proper targets
2. Port shared code from LoOptimizer
3. Implement drum loop detection MVP
4. Test on 10-20 diverse songs
5. Iterate on accuracy

### Notion Documentation
See: [LoopLifter Project Page](https://www.notion.so/306fa1b2ddff813e9af3da36ac53153a)
