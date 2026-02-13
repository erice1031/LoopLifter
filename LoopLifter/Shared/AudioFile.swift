//
//  AudioFile.swift
//  LoopLifter
//
//  Audio file model representing loaded audio with analysis data
//  Shared with LoOptimizer
//

import Foundation
import AVFoundation

/// Represents an audio file loaded into the app with analysis metadata
@Observable
class AudioFile {
    let url: URL
    let asset: AVAsset
    private var isAccessingSecurityScope: Bool = false

    var duration: TimeInterval = 0
    var sampleRate: Double = 44100
    var channels: Int = 2

    // Analysis results
    var detectedTempo: Double?
    var onsets: [TimeInterval] = []  // Beat/onset times in seconds
    var peaks: [Float] = []  // Amplitude peaks for waveform display

    // Quantization
    var quantizationSettings = QuantizationSettings()
    var quantizedOnsets: [TimeInterval] = []

    init(url: URL) throws {
        self.url = url
        // Start accessing security-scoped resource for sandboxed apps
        self.isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
        self.asset = AVURLAsset(url: url)

        // Load basic audio properties
        Task {
            await loadAudioProperties()
        }
    }

    deinit {
        if isAccessingSecurityScope {
            url.stopAccessingSecurityScopedResource()
        }
    }

    @MainActor
    private func loadAudioProperties() async {
        do {
            // Load duration
            self.duration = try await asset.load(.duration).seconds

            // Load audio tracks
            let tracks = try await asset.load(.tracks)
            guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
                print("No audio track found")
                return
            }

            // Get format descriptions
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                if let asbd = audioStreamBasicDescription {
                    self.sampleRate = asbd.pointee.mSampleRate
                    self.channels = Int(asbd.pointee.mChannelsPerFrame)
                }
            }

            print("✅ Loaded: \(url.lastPathComponent)")
            print("   Duration: \(duration)s, Sample Rate: \(sampleRate)Hz, Channels: \(channels)")

        } catch {
            print("❌ Failed to load audio properties: \(error)")
        }
    }

    /// Generate waveform peaks for visualization
    @MainActor
    func generateWaveformPeaks(targetSamples: Int = 500) async throws {
        let reader = try AVAssetReader(asset: asset)

        guard let audioTrack = try await asset.load(.tracks).first(where: { $0.mediaType == .audio }) else {
            throw AudioFileError.noAudioTrack
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var allSamples: [Float] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)

            _ = data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
            }

            let samples = data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Int16.self))
            }

            allSamples.append(contentsOf: samples.map { Float($0) / Float(Int16.max) })
        }

        // Downsample to target number of peaks
        let stride = max(1, allSamples.count / targetSamples)
        var peaks: [Float] = []

        for i in Swift.stride(from: 0, to: allSamples.count, by: stride) {
            let end = min(i + stride, allSamples.count)
            let chunk = allSamples[i..<end]
            let peak = chunk.map { abs($0) }.max() ?? 0
            peaks.append(peak)
        }

        self.peaks = peaks
        print("✅ Generated \(peaks.count) waveform peaks")
    }

    /// Apply quantization to onsets based on current settings
    func applyQuantization() {
        guard let tempo = detectedTempo, tempo > 0 else {
            quantizedOnsets = onsets
            return
        }

        if quantizationSettings.isEnabled {
            quantizedOnsets = onsets.map { onset in
                quantizationSettings.quantize(onset: onset, tempo: tempo, duration: duration)
            }
        } else {
            quantizedOnsets = onsets
        }
    }
}

enum AudioFileError: LocalizedError {
    case noAudioTrack
    case invalidFormat
    case analysisFailure(String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .invalidFormat:
            return "Unsupported audio format"
        case .analysisFailure(let reason):
            return "Analysis failed: \(reason)"
        }
    }
}
