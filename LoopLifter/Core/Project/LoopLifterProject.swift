//
//  LoopLifterProject.swift
//  LoopLifter
//
//  Project file model for saving/loading analysis state
//

import Foundation

/// Represents a saved LoopLifter project
struct LoopLifterProject: Codable {
    /// Project file format version
    static let formatVersion = 1

    /// Project metadata
    var version: Int = formatVersion
    var name: String
    var createdAt: Date
    var modifiedAt: Date

    /// Original audio file info
    var originalAudioPath: String
    var originalAudioName: String

    /// Detected tempo
    var tempo: Double

    /// Extracted samples
    var samples: [SampleData]

    /// Sample data (Codable version of ExtractedSample)
    struct SampleData: Codable, Identifiable {
        var id: UUID
        var name: String
        var category: String  // "loop", "hit", "fill", "phrase"
        var stemType: String  // "drums", "bass", "vocals", "other"
        var startTime: TimeInterval
        var endTime: TimeInterval
        var duration: TimeInterval
        var barLength: Int?
        var confidence: Double
        var tempo: Double
        var nudgeOffset: TimeInterval

        init(from sample: ExtractedSample) {
            self.id = sample.id
            self.name = sample.name
            self.category = sample.category.rawValue
            self.stemType = sample.stemType.rawValue
            self.startTime = sample.startTime
            self.endTime = sample.endTime
            self.duration = sample.duration
            self.barLength = sample.barLength
            self.confidence = sample.confidence
            self.tempo = sample.tempo
            self.nudgeOffset = sample.nudgeOffset
        }

        func toExtractedSample(audioURL: URL?) -> ExtractedSample {
            var sample = ExtractedSample(
                id: id,
                name: name,
                category: SampleCategory(rawValue: category) ?? .hit,
                stemType: StemType(rawValue: stemType) ?? .other,
                duration: duration,
                barLength: barLength,
                confidence: confidence
            )
            sample.startTime = startTime
            sample.endTime = endTime
            sample.tempo = tempo
            sample.nudgeOffset = nudgeOffset
            sample.audioURL = audioURL
            return sample
        }
    }

    // MARK: - Initialization

    init(name: String, audioURL: URL, tempo: Double, samples: [ExtractedSample]) {
        self.name = name
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.originalAudioPath = audioURL.path
        self.originalAudioName = audioURL.lastPathComponent
        self.tempo = tempo
        self.samples = samples.map { SampleData(from: $0) }
    }

    // MARK: - File Operations

    /// Save project to a file
    func save(to url: URL) throws {
        var project = self
        project.modifiedAt = Date()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(project)
        try data.write(to: url)

        print("💾 Saved project: \(url.lastPathComponent)")
    }

    /// Load project from a file
    static func load(from url: URL) throws -> LoopLifterProject {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let project = try decoder.decode(LoopLifterProject.self, from: data)

        print("📂 Loaded project: \(project.name) (\(project.samples.count) samples)")
        return project
    }

    // MARK: - Sample Restoration

    /// Restore ExtractedSample objects with audio URLs from cache
    func restoreSamples() -> [ExtractedSample] {
        let originalURL = URL(fileURLWithPath: originalAudioPath)

        // Try to get cached stems
        guard let cachedStems = StemCache.shared.getCachedStems(for: originalURL) else {
            print("⚠️ Cached stems not found for: \(originalAudioName)")
            print("   Re-analyze the original file to rebuild cache")
            return []
        }

        // Restore samples with correct audio URLs
        return samples.compactMap { sampleData -> ExtractedSample? in
            guard let stemType = StemType(rawValue: sampleData.stemType),
                  let audioURL = cachedStems[stemType] else {
                return nil
            }
            return sampleData.toExtractedSample(audioURL: audioURL)
        }
    }
}
