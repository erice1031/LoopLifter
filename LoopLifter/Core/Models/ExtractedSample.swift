//
//  ExtractedSample.swift
//  LoopLifter
//
//  Represents an extracted audio sample
//

import Foundation

/// A sample extracted from the analysis process
struct ExtractedSample: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var category: SampleCategory
    var stemType: StemType
    var duration: TimeInterval
    var barLength: Int?  // For loops: 1, 2, or 4 bars
    var confidence: Double  // 0.0 to 1.0

    // Audio data
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var audioURL: URL?

    // Export selection
    var isSelected: Bool = true

    /// Formatted duration string
    var durationString: String {
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.1fs", duration)
        }
    }

    /// Bar length description
    var barDescription: String? {
        guard let bars = barLength else { return nil }
        return bars == 1 ? "1 bar" : "\(bars) bars"
    }

    /// Confidence as percentage
    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

/// Categories of extracted samples
enum SampleCategory: String, CaseIterable, Codable {
    case loop = "Loop"
    case fill = "Fill"
    case roll = "Roll"
    case hit = "Hit"
    case phrase = "Phrase"
    case hook = "Hook"
    case adlib = "Ad-lib"
    case chop = "Chop"
    case chord = "Chord"
    case riff = "Riff"
    case note = "Note"
    case fx = "FX"

    var icon: String {
        switch self {
        case .loop: return "repeat"
        case .fill: return "waveform.path"
        case .roll: return "forward.fill"
        case .hit: return "circle.fill"
        case .phrase: return "text.quote"
        case .hook: return "star.fill"
        case .adlib: return "bubble.left.fill"
        case .chop: return "scissors"
        case .chord: return "pianokeys"
        case .riff: return "guitars.fill"
        case .note: return "music.note"
        case .fx: return "sparkles"
        }
    }
}

/// Stem types (mirrors LoOptimizer)
enum StemType: String, CaseIterable, Codable {
    case drums = "drums"
    case bass = "bass"
    case vocals = "vocals"
    case other = "other"

    var displayName: String {
        switch self {
        case .drums: return "Drums"
        case .bass: return "Bass"
        case .vocals: return "Vocals"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .drums: return "drum.fill"
        case .bass: return "guitars.fill"
        case .vocals: return "mic.fill"
        case .other: return "pianokeys"
        }
    }

    var color: String {
        switch self {
        case .drums: return "orange"
        case .bass: return "purple"
        case .vocals: return "green"
        case .other: return "blue"
        }
    }
}
