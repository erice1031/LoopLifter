# 🎯 LoopLifter

**AI-powered sample pack generator - extract loops, hits, and phrases from any song.**

Part of the **"Lo" Suite** of audio production tools.

---

## Overview

LoopLifter takes any audio file, separates it into stems using AI (Demucs), then intelligently analyzes each stem to automatically extract production-ready samples:

- 🥁 **Drums**: Main loops, fills, rolls, individual hits (kick, snare, hat)
- 🎸 **Bass**: Riffs, single notes, slides
- 🎤 **Vocals**: Hooks, phrases, ad-libs, vocal chops
- 🎹 **Other**: Guitar/synth loops, chord stabs, leads, FX

Output: Organized sample packs ready for any DAW or sampler.

## Features

### Intelligent Extraction
- **Loop Detection** - Finds repeating patterns using self-similarity analysis
- **Fill Detection** - Identifies transitions and fills at phrase boundaries
- **Hit Isolation** - Extracts single hits from sparse regions
- **Phrase Detection** - Segments vocals and melodic content

### Export Options
- WAV/AIFF with proper naming
- Organized folder structure by stem and category
- Metadata JSON with tempo, key, timestamps
- (Coming) Ableton, Logic, Kontakt format exports

### Simple Workflow
1. Drop any audio file
2. Click Analyze
3. Preview and select samples
4. Export as sample pack

## Requirements

- macOS 14.0+
- Python 3.11+ (for Demucs)
- FFmpeg (`brew install ffmpeg`)
- Demucs (`pip install demucs`)

## Installation

```bash
# Clone the repo
git clone https://github.com/erice1031/LoopLifter.git

# Install Python dependencies (in a venv)
python3 -m venv ~/demucs-env
source ~/demucs-env/bin/activate
pip install demucs

# Install FFmpeg
brew install ffmpeg

# Open in Xcode
open LoopLifter.xcodeproj
```

## Usage

1. Launch LoopLifter
2. Drag any audio file onto the drop zone (or click Browse)
3. Wait for stem separation and analysis
4. Review detected samples - preview with play buttons
5. Select samples to export (all selected by default)
6. Click "Export All" or "Export Selected"
7. Choose destination folder

## Technical Details

### Analysis Algorithms

**Self-Similarity Matrix**
- Computes audio features per beat/bar
- Builds similarity matrix to find repeating patterns
- Most repeated pattern = main loop

**Novelty Detection**
- Measures spectral change over time
- Peaks indicate structural changes
- Used to find fills and transitions

**Hit Isolation**
- Finds onsets with silence before/after
- Classifies by spectral content
- Extracts individual drum hits

### Project Structure

```
LoopLifter/
├── Core/
│   ├── Analysis/          # Detection algorithms
│   ├── Extraction/        # Per-stem extractors
│   ├── Export/            # Format exporters
│   └── Models/            # Data models
├── Views/                 # SwiftUI views
└── Shared/                # Shared with LoOptimizer
```

## Related Projects

- **[LoOptimizer](https://github.com/erice1031/LoOptimizer)** - AI-powered remix studio
- **LoAudioKit** - Shared audio processing library (coming soon)

## Roadmap

- [x] Project setup and architecture
- [ ] Drum loop detection MVP
- [ ] Bass riff detection
- [ ] Vocal phrase detection
- [ ] WAV export with metadata
- [ ] Ableton Live Pack export
- [ ] Logic Pro Sampler export
- [ ] Batch processing

## License

MIT License - see LICENSE file

## Contributing

Contributions welcome! Please read CONTRIBUTING.md first.

---

*Made with ☕ and 🎵 by Eric Erwin*
