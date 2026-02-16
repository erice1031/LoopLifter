//
//  ExtractedSample.swift
//  LoopLifter
//
//  Represents an extracted audio sample
//

import Foundation

/// A sample extracted from the analysis process
struct ExtractedSample: Identifiable, Hashable {
    let id: UUID
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
    var tempo: Double = 120.0  // BPM for quantization

    // Nudge offset (in seconds, added to startTime)
    var nudgeOffset: TimeInterval = 0

    // Export selection
    var isSelected: Bool = true

    // Computed effective times (with nudge applied)
    var effectiveStartTime: TimeInterval {
        startTime + nudgeOffset
    }

    var effectiveEndTime: TimeInterval {
        endTime + nudgeOffset
    }

    init(id: UUID = UUID(), name: String, category: SampleCategory, stemType: StemType, duration: TimeInterval, barLength: Int?, confidence: Double) {
        self.id = id
        self.name = name
        self.category = category
        self.stemType = stemType
        self.duration = duration
        self.barLength = barLength
        self.confidence = confidence
    }

    /// Create a duplicate with a new ID
    func duplicate() -> ExtractedSample {
        var copy = ExtractedSample(
            id: UUID(),
            name: "\(name) Copy",
            category: category,
            stemType: stemType,
            duration: duration,
            barLength: barLength,
            confidence: confidence
        )
        copy.startTime = startTime
        copy.endTime = endTime
        copy.audioURL = audioURL
        copy.tempo = tempo
        copy.nudgeOffset = nudgeOffset
        copy.isSelected = isSelected
        return copy
    }

    /// Get nudge step size for a given grid resolution
    func nudgeStepSize(for grid: NudgeGrid) -> TimeInterval {
        let beatDuration = 60.0 / tempo
        return beatDuration / Double(grid.divisor)
    }

    /// Format position as bars:beats
    func positionString(for time: TimeInterval) -> String {
        let beatDuration = 60.0 / tempo
        let totalBeats = time / beatDuration
        let bars = Int(totalBeats / 4) + 1
        let beats = Int(totalBeats.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bars):\(beats)"
    }

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

// Note: StemType is defined in Shared/StemSeparator.swift

/// Grid resolution for nudging sample start times
enum NudgeGrid: String, CaseIterable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    var divisor: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .sixteenth: return 4
        case .thirtySecond: return 8
        }
    }

    var displayName: String {
        rawValue
    }
}
