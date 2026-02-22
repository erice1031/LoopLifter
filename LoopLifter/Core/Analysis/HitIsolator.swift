//
//  HitIsolator.swift
//  LoopLifter
//
//  Isolates single hits (kick, snare, hat) from sparse regions
//

import Foundation
import AVFoundation
import Accelerate

/// Isolates single drum hits and one-shots from audio
class HitIsolator {

    /// Find isolated hits in audio based on onset density
    /// - Parameters:
    ///   - onsets: Detected onset times
    ///   - duration: Total audio duration
    ///   - minGapBefore: Minimum silence before hit (seconds)
    ///   - minGapAfter: Minimum silence after hit (seconds)
    /// - Returns: Time ranges of isolated hits
    static func findIsolatedHits(
        onsets: [TimeInterval],
        duration: TimeInterval,
        minGapBefore: TimeInterval = 0.3,
        minGapAfter: TimeInterval = 0.2
    ) -> [IsolatedHit] {
        guard onsets.count > 1 else { return [] }

        var hits: [IsolatedHit] = []
        let sortedOnsets = onsets.sorted()

        for i in 0..<sortedOnsets.count {
            let onset = sortedOnsets[i]

            // Check gap before
            let gapBefore: TimeInterval
            if i == 0 {
                gapBefore = onset  // Gap from start
            } else {
                gapBefore = onset - sortedOnsets[i - 1]
            }

            // Check gap after
            let gapAfter: TimeInterval
            if i == sortedOnsets.count - 1 {
                gapAfter = duration - onset  // Gap to end
            } else {
                gapAfter = sortedOnsets[i + 1] - onset
            }

            // Is this hit sufficiently isolated?
            if gapBefore >= minGapBefore && gapAfter >= minGapAfter {
                // Estimate hit duration (until next onset or gap limit)
                let hitDuration = min(gapAfter, 0.5)  // Max 500ms per hit

                hits.append(IsolatedHit(
                    startTime: onset,
                    duration: hitDuration,
                    gapBefore: gapBefore,
                    gapAfter: gapAfter
                ))
            }
        }

        return hits
    }

    /// Classify drum hits by spectral characteristics using FFT analysis.
    /// Reads the audio file once and classifies each hit by band energy,
    /// spectral centroid, and attack time.
    static func classifyDrumHits(
        audioURL: URL,
        hits: [IsolatedHit]
    ) async throws -> [ClassifiedHit] {
        guard !hits.isEmpty else { return [] }

        let asset = AVURLAsset(url: audioURL)
        let tracks = try await asset.load(.tracks)
        guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
            throw HitIsolatorError.noAudioTrack
        }

        // Resolve actual sample rate from the format description
        var sampleRate: Double = 44100
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        if let format = formatDescriptions.first,
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) {
            sampleRate = asbd.pointee.mSampleRate
        }

        // Read entire file as mono Float32 samples (one pass — efficient)
        let allSamples = try readAllMonoSamples(asset: asset, audioTrack: audioTrack)

        return hits.map { hit in
            let startSample = Int(hit.startTime * sampleRate)
            let endSample   = min(allSamples.count, startSample + Int(hit.duration * sampleRate))

            guard startSample < allSamples.count, endSample > startSample else {
                return ClassifiedHit(hit: hit, drumType: .percussion, confidence: 0.3)
            }

            let hitSamples = Array(allSamples[startSample..<endSample])

            guard hitSamples.count >= 64 else {
                return ClassifiedHit(hit: hit, drumType: .percussion, confidence: 0.3)
            }

            let (type, confidence) = classifyBySpectrum(
                samples: hitSamples,
                sampleRate: sampleRate,
                hitDuration: hit.duration
            )
            return ClassifiedHit(hit: hit, drumType: type, confidence: confidence)
        }
    }

    // MARK: - Sample reading

    /// Read the full audio file as mono Float32 PCM samples.
    /// AVFoundation downmixes to mono automatically via AVNumberOfChannelsKey.
    private static func readAllMonoSamples(
        asset: AVURLAsset,
        audioTrack: AVAssetTrack
    ) throws -> [Float] {
        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1  // Downmix to mono
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []

        while let buffer = output.copyNextSampleBuffer(),
              let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var data = Data(count: length)
            _ = data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
            }
            data.withUnsafeBytes { ptr in
                samples.append(contentsOf: ptr.bindMemory(to: Float.self))
            }
        }

        return samples
    }

    // MARK: - Spectral classification

    /// Classify a window of samples using FFT-derived features:
    /// band energy ratios, spectral centroid, and attack time.
    private static func classifyBySpectrum(
        samples: [Float],
        sampleRate: Double,
        hitDuration: TimeInterval
    ) -> (DrumHitType, Float) {
        let fftSize  = 2048
        let halfSize = fftSize / 2
        let log2n    = vDSP_Length(log2(Float(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            return (.percussion, 0.3)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Pad or truncate to fftSize, then apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        let copyCount = min(samples.count, fftSize)
        windowed[0..<copyCount] = ArraySlice(samples[0..<copyCount])

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack real data as split complex (even → real, odd → imag), then FFT
        var realPart  = [Float](repeating: 0, count: halfSize)
        var imagPart  = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        windowed.withUnsafeBufferPointer { wPtr in
            realPart.withUnsafeMutableBufferPointer { rPtr in
                imagPart.withUnsafeMutableBufferPointer { iPtr in
                    var split = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                    wPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, Int32(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
                }
            }
        }

        // Frequency resolution per bin
        let freqRes = sampleRate / Double(fftSize)

        // Band boundaries in bin indices
        // Low:  20–200 Hz  (sub-bass, fundamental of kick/tom)
        // Mid:  200–2000 Hz (body of snare, clap, rim)
        // High: 2000–18000 Hz (hats, cymbals, sizzle)
        let binLow      = max(1,          Int( 20.0  / freqRes))
        let binLowMid   = max(1,          Int(200.0  / freqRes))
        let binMidHigh  = min(halfSize-1, Int(2000.0 / freqRes))
        let binHighTop  = min(halfSize-1, Int(18000.0 / freqRes))

        let lowEnergy   = magnitudes[binLow...binLowMid].reduce(0, +)
        let midEnergy   = magnitudes[binLowMid...binMidHigh].reduce(0, +)
        let highEnergy  = magnitudes[binMidHigh...binHighTop].reduce(0, +)
        let totalEnergy = lowEnergy + midEnergy + highEnergy

        guard totalEnergy > 0 else { return (.percussion, 0.3) }

        let lowRatio  = lowEnergy  / totalEnergy
        let midRatio  = midEnergy  / totalEnergy
        let highRatio = highEnergy / totalEnergy

        // Spectral centroid — frequency-weighted center of mass
        var weightedFreq: Float = 0
        var magSum: Float = 0
        for i in binLow...binHighTop {
            let freq = Float(i) * Float(freqRes)
            weightedFreq += freq * magnitudes[i]
            magSum       += magnitudes[i]
        }
        let centroid = magSum > 0 ? weightedFreq / magSum : 0

        // Attack time — samples to reach 90% of peak amplitude
        let peakAmp = samples.map { abs($0) }.max() ?? 0
        var attackIdx = 0
        if peakAmp > 0 {
            for (i, s) in samples.enumerated() {
                if abs(s) >= peakAmp * 0.9 { attackIdx = i; break }
            }
        }
        let attackSec = Float(attackIdx) / Float(sampleRate)

        let dur = Float(hitDuration)

        // ── Classification rules ──────────────────────────────────────────
        // Ordered from most specific to most general.

        // Kick: strong sub-bass, low centroid
        if centroid < 250 && lowRatio > 0.45 {
            return (.kick, min(1.0, lowRatio * 1.6))
        }

        // Tom: low-mid centroid, sustained body, less sub than kick
        if centroid < 600 && lowRatio > 0.28 && dur > 0.12 {
            return (.tom, min(1.0, (lowRatio + midRatio) * 0.9))
        }

        // Clap: mid-high centroid, extremely sharp attack, short
        if centroid > 800 && centroid < 3500 && attackSec < 0.004 && dur < 0.12 {
            return (.clap, 0.75)
        }

        // Rim shot: mid-high centroid, very short, not as sharp as clap
        if centroid > 500 && centroid < 2000 && dur < 0.09 {
            return (.rim, 0.65)
        }

        // Snare: mid-band dominant, medium centroid
        if centroid >= 200 && centroid < 2000 && midRatio > 0.30 {
            return (.snare, min(1.0, midRatio * 1.5))
        }

        // Cymbal: high centroid, longer sustain (ride, crash, open hat)
        if centroid > 3000 && dur > 0.18 {
            return (.cymbal, min(1.0, highRatio * 1.6))
        }

        // Hi-hat: high-band dominant or high centroid, short/medium
        if highRatio > 0.40 || centroid > 4000 {
            return (.hihat, min(1.0, highRatio * 1.5 + 0.2))
        }

        // Fallback
        return (.percussion, 0.4)
    }
}

// MARK: - Supporting types

/// An isolated hit with timing info
struct IsolatedHit {
    let startTime: TimeInterval
    let duration: TimeInterval
    let gapBefore: TimeInterval
    let gapAfter: TimeInterval
}

/// A hit with drum type classification
struct ClassifiedHit {
    let hit: IsolatedHit
    let drumType: DrumHitType
    let confidence: Float
}

/// Types of drum hits
enum DrumHitType: String, CaseIterable {
    case kick        = "Kick"
    case snare       = "Snare"
    case hihat       = "HiHat"
    case tom         = "Tom"
    case clap        = "Clap"
    case rim         = "Rim"
    case cymbal      = "Cymbal"
    case percussion  = "Percussion"

    var icon: String {
        switch self {
        case .kick:       return "circle.fill"
        case .snare:      return "circle.bottomhalf.filled"
        case .hihat:      return "triangle.fill"
        case .tom:        return "circle.dashed"
        case .clap:       return "hands.clap.fill"
        case .rim:        return "circle.circle"
        case .cymbal:     return "star.fill"
        case .percussion: return "waveform"
        }
    }
}

enum HitIsolatorError: LocalizedError {
    case noAudioTrack

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "No audio track found in file"
        }
    }
}
